# Headless note-vault CLI selection and setup

Use this when Hermes needs durable filesystem access to an Obsidian vault from a server/container without a graphical desktop.

## Choose the correct official component

Distinguish the two official command-line products:

- **Obsidian CLI (`obsidian`)** controls a running Obsidian desktop application. It is not the clean default for a display-less server.
- **Obsidian Headless (`ob`)** is the standalone client for Obsidian Sync/Publish. It requires no desktop app and is appropriate for an agent container whose real work happens through Markdown file tools.

Do not install an unrelated third-party package merely because it owns the `obsidian-cli` name on npm. Verify publisher/repository and prefer the official `obsidian-headless` package for server sync.

## Installation in Luke's Hermes container

The maintained user-local npm prefix is `/config/.npm-global`, already on `PATH`. Pin a verified release when installing:

```bash
npm --prefix /config/.npm-global install -g obsidian-headless@<version>
/config/.npm-global/bin/ob --version
/config/.npm-global/bin/ob --help
```

Verified on 2026-08-13 with `obsidian-headless@0.0.14`; it requires Node.js 22 or later. Treat that version as dated and re-check the official repository/npm metadata before future installs or upgrades.

## Default vault path

The bundled Obsidian filesystem skill already falls back to:

```text
~/Documents/Obsidian Vault
```

In this Home Assistant add-on container, `HOME=/config`, so the concrete default is:

```text
/config/Documents/Obsidian Vault
```

Use that path unless the user has an existing local mount or explicitly prefers another location. Do **not** add `OBSIDIAN_VAULT_PATH` merely to restate the default. The path may legitimately be absent before the first remote-vault setup; that alone is not a configuration fault.

## Supported setup shape

After authenticated account access is available:

```bash
ob sync-list-remote --json
ob sync-setup --vault "<existing remote vault>" \
  --path "/config/Documents/Obsidian Vault" \
  --device-name "Hermes"
ob sync --path "/config/Documents/Obsidian Vault"
```

For end-to-end encrypted vaults, the vault encryption password is separately required by `sync-setup`; do not assume the Obsidian account password is sufficient.

## Credential discipline

- Prefer the established scoped Proton Pass agent when a matching login already exists.
- Inspect login metadata first and select the exact item before resolving username/password fields.
- Inject credentials directly into the waiting login process or via a protected temporary channel; never print them, put them in shell history, memory, skills, or reports.
- MFA and vault-encryption prompts are separate stages. Handle only after the CLI requests them.
- Do not create an empty remote vault as a substitute for locating the user's existing one.

## Verification

Installation is not complete vault setup. Require all of the following before claiming usable note access:

1. `ob --version` and `ob --help` succeed.
2. `ob sync-list-remote --json` lists authenticated remote vaults.
3. `ob sync-list-local --json` shows the intended local path.
4. An initial `ob sync` succeeds.
5. The default vault contains real Markdown content from the remote vault.
6. Read/search one real note through Hermes file tools using the concrete absolute path.
7. Only then configure a durable continuous-sync process, and verify it survives the intended service/container lifecycle.

Do not claim a configured vault when only the package installation passed or the local-vault list is empty.
