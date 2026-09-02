---
name: proton-pass-cli
description: Set up and use the official Proton Pass CLI for scoped, audited agent access to secrets in headless/container Hermes environments.
author: Luke
---

# Proton Pass CLI

Use this skill when setting up, troubleshooting, or using Proton Pass from Hermes/CLI, especially for agent-scoped secret access.

## Preferred Approach

1. **Install the official CLI conventionally.** Prefer Homebrew when available:
   ```bash
   brew tap protonpass/tap
   brew install protonpass/tap/pass-cli
   pass-cli --version
   ```
   The installed binary is `pass-cli`. Without Homebrew, use Proton's installer (`curl -fsSL https://proton.me/download/pass-cli/install.sh | bash`), which places the binary in `~/.local/bin`.

   To update an installer-based binary, stop any service that execs it (the SSH agent holds the file open and `cp` fails with `Text file busy`), then run `pass-cli update --yes` or re-run the installer. Restart `proton-pass-cli-autologin.service` afterward. Unset container/agent `PROTON_PASS_SESSION_DIR` and `PROTON_PASS_KEY_PROVIDER` before updating a desktop keyring session. Homebrew installs must use `brew upgrade pass-cli`; `pass-cli update` will not replace them.

2. **Use container-safe local storage.** In Home Assistant add-ons, Docker containers, and other headless environments, avoid assuming a desktop keyring or persistent Linux kernel keyring. Set a dedicated session dir and filesystem key provider:
   ```bash
   export PROTON_PASS_SESSION_DIR="<persistent-session-dir>"
   export PROTON_PASS_KEY_PROVIDER=fs
   export PROTON_PASS_DISABLE_TELEMETRY=1
   export PASS_LOG_LEVEL=warn
   ```
   Lock down the state directory and files with `0700` dirs and `0600` files.

3. **Create a wrapper instead of scattering env vars.** Use a dedicated local wrapper that sets PATH, `PROTON_PASS_SESSION_DIR`, `PROTON_PASS_KEY_PROVIDER=fs`, quiet logging, and telemetry opt-out before execing `pass-cli`. Resolve Luke's exact wrapper and state paths from `~/.agents/private-context.md`.

4. **Prefer agent tokens for Hermes.** Proton Pass CLI 2.x supports `pass-cli agent ...`, which is better than a broad full-account session for autonomous agents. Agents are scoped, expiring personal access tokens with access logs. Use:
   ```bash
   pass-cli agent create --expiration 1m "Hermes"
   pass-cli agent access grant "Hermes" --vault-name "..." --role viewer
   pass-cli agent instructions "Hermes"
   ```
   Exact commands and flags may vary by CLI version; run `pass-cli agent --help` before issuing side-effecting commands.

5. **Always provide an audit reason for agent reads/writes.** Agent sessions require `PROTON_PASS_AGENT_REASON` for audited operations such as `item view`, item create/update/trash/move, and vault update:
   ```bash
   PROTON_PASS_AGENT_REASON="Need SSH key to troubleshoot Proxmox" pass-cli item view \
     --vault-name "<vault>" \
     --item-title "<ssh-item>" \
     --field password
   ```

6. **Use secret references for command execution.** For scripts or env injection, prefer `pass-cli run` / `pass-cli inject` with `pass://SHARE_ID/ITEM_ID[/FIELD]` references so secrets do not get printed or stored in shell history.

## Security Rules

- Never store or repeat Proton credentials, personal access tokens, agent tokens, callback payloads, passwords, public-share passwords/fragments, archive passwords, or item secret values in memory, skills, or final summaries. Treat one-time delivery passwords as credentials too; if one is accidentally persisted, delete that memory immediately and disclose the cleanup to the user.
- Redact token-like strings as `[REDACTED]`.
- Do not pass PATs on the command line if an environment variable or file-based handoff is available; command-line args may leak via process listings or history.
- If a user pastes a PAT in chat and asks to save it, do not save the literal token; use the existing secure env file/wrapper path or ask for a secure handoff if needed.
- Prefer viewer-scoped, item- or vault-limited access with short expiration.
- Before granting broad vault access or editor/manager roles, confirm the intended scope with the user.

## Session Discipline

Before any `pass-cli` command, verify the session with `pass-cli info` or the Hermes wrapper equivalent. If it fails with an authentication/session error, read the full output, run `pass-cli logout --force` if needed, re-authenticate via the secure PAT env/wrapper (not by printing or saving the token), verify `pass-cli info`, then retry the original command. During long-running tasks, check `info` periodically. After login/setup, verify access with:

```bash
pass-cli vault list --output json
pass-cli share list --output json
```

## Verification

After setup/login:

```bash
proton-pass-agent --version
proton-pass-agent info
PROTON_PASS_AGENT_REASON="Verification read" proton-pass-agent item view --help
```

For unauthenticated setups, `pass-cli info` should fail cleanly with an authenticated-client error.

### Scoped SSH agent for Git operations

When a headless host needs Git SSH authentication, start the CLI's native daemon through the scoped wrapper instead of exporting a private key or falling back to an expired HTTPS token:

```bash
PROTON_PASS_AGENT_REASON="Authenticate Git remote" proton-pass-agent ssh-agent daemon start \
  --socket-path "<ssh-agent-socket>" \
  --vault-name "<scoped-vault>" \
  --pid-file "<ssh-agent-pid-file>" \
  --log-file "<ssh-agent-log-file>"
```

The first status check can briefly report `degraded` while keys are loading. Wait for the socket with a bounded retry, require `ssh-agent daemon status` to report `running`, then verify identities with `SSH_AUTH_SOCK="<ssh-agent-socket>" ssh-add -l`. For a new Git host, compare the scanned host-key fingerprint with the provider's official documentation before adding a scoped `known_hosts` entry. Test `ssh -T` before changing the remote and pushing. Keep the socket, PID, log, vault, and remote values in host-local configuration or the private context, not in this skill.

## CLI syntax notes (2.2.4+)

- `pass-cli test` was removed in 2.2.4. Verify a session with `pass-cli info` (or `info --output json`). Confirm vault access with `vault list` / `share list` as needed. Login helpers and health checks must not call `test`.
- `pass-cli item list` accepts the vault as a positional argument or `--vault-name` (both work as of 2.2.3):
  ```bash
  proton-pass-agent item list "<vault>" --output json
  ```
- A global `item list --output json` can fail if no default vault is set. Prefer an explicit vault for deterministic automation.
- When locating credentials, use `item list "<Vault>" --filter-type login --output json` before resolving `/username` or `/password`. Recursive searches across every item type can mistake email aliases for login records because alias titles often look like account usernames; aliases correctly fail with `Field 'username' not found`.
- When scanning item metadata for candidate SSH/host credentials, summarize only title/type/state; redact vault/share/item IDs and never print secret fields.
- If `--output json` from `pass-cli item list` contains literal control characters and `json.loads` fails, use Hermes `execute_code`'s `json_parse()` helper instead of printing or hand-cleaning the JSON. Continue to redact IDs and secret fields in any summary.

## Agent Role Limitations, Write Operations, and REASON Constraints

Luke's scoped agent token is usually granted only **viewer** role for least privilege. Resolve its local wrapper and approved vault scope from `~/.agents/private-context.md`. This is safe for discovery but restrictive for writes:

- Successful with REASON: `info`, `vault list`, `item list "<Vault>" --output json`, `item view`.
- Fails with "Could not perform operation. Reason: NotAllowed" (or similar): `item create`, `item create note`, `item update`, adding custom fields, or editing existing logins/aliases.

When a task requires persisting a discovered secret, use the agent **only for read/discovery**. After the user supplies the value, perform the actual storage manually in the Proton Pass app as a purpose-named note or custom field on the appropriate item. Resolve existing item and alias names from the private context; do not keep retrying writes through a viewer agent.

Likewise, do not use account credentials readable by the viewer agent to bootstrap a broad owner/full-account CLI session merely to bypass the viewer role. If a generated operational credential must be consumed before a human can save it in Pass, use a narrowly scoped root-only local secret (`0700` parent, `0600` file), keep it out of logs and argv, clearly report the remaining manual Pass-save step, and remove the local copy after Pass-backed injection is verified. This is a temporary handoff pattern, not a replacement for Proton Pass.

`PROTON_PASS_AGENT_REASON` must be short (< ~300 characters). Overly long or narrative reasons are rejected at the agent layer before the operation is attempted. Keep them concise and specific (e.g. "Locate UniFi API key for router DHCP DNS fix").

**Proven one-shot pattern for API keys (observed in router DHCP work):**
1. Agent + short REASON to list and locate the item (redact IDs in summaries).
2. User pastes or confirms the key value in chat.
3. Use directly in terminal for the duration of the task only: `export KEY=...; curl -k -H "X-API-Key: $KEY" ...` (never echo the value, never write it to files or memory).
4. Redact the literal key as `[REDACTED]` in all tool output, thinking, and final messages.
5. Tell the user to add it manually in the app for future use.

This pattern keeps the audit trail while respecting role limits.

## Troubleshooting: missing or corrupted local session in a headless add-on

Resolve the wrapper, token env file, session directory, SSH-agent paths, and watchdog from `~/.agents/private-context.md`; do not persist them in this skill.

1. Run the wrapper's `info` command.
2. If no authenticated client exists, confirm the scoped PAT is available to the wrapper as an exported environment variable, then run the wrapper's login command. Never put the PAT in argv.
3. For local decrypt/aead corruption, move the existing session directory to a timestamped sibling backup, recreate it with mode `0700`, and retry login.
4. Apply mode `0700` to state directories and `0600` to state files.
5. Verify vault listing and one permitted item operation before restarting dependent services.
6. Run the durable watchdog and require silent success. Do not depend on add-on system-service paths that disappear across container restarts.
7. Remove the corrupt-session backup only after the replacement session and dependent SSH agent are verified.

Always set a short, specific `PROTON_PASS_AGENT_REASON`. When the user says they approved after a timeout, reissue the operation; delayed phone approval is not refusal.

## Vault Migration, Native Archives, and Reconciliation

For password-manager round trips, do not import one populated vault directly over another when deduplication is required. Export both sides, reconcile locally into a clean native Proton archive, preserve conflicting older copies in a review vault, and verify before retiring either source. Treat third-party passkey conversion as experimental until each credential authenticates successfully against its real relying party.

When generating or validating a native archive, derive the contract from commit-pinned `proton-webclients` export/import source rather than guessing from example exports. Do not access user exports unless explicitly authorized; use source inspection and synthetic fixtures. Preserve Proton passkey objects as opaque Base64/MessagePack state. Remember that vault IDs, item IDs, pin state, vault display metadata, and input content-format versions are not restored, and attachment linking can advance the backend-controlled final modification time.

See:

- `references/native-export-schema.md` for exact ZIP paths, field paths, passkeys, attachments, timestamp behavior, and validation/import pitfalls.
- `references/bitwarden-roundtrip-migration.md` for timestamp-based reconciliation, conservative duplicate matching, trash/alias handling, current Bitwarden/CXP limitations, and native-Proton passkey conversion requirements.
- `references/passkey-canary-and-secure-handoff.md` for a one-entry passkey canary, full cryptographic/native-archive validation, and password-protected AES delivery without exposing the password in argv or chat.
- `references/proton-drive-public-share-retrieval.md` for securely downloading password-protected public-share exports, Base64URL/link parsing, current browser selectors, permission hardening, and completion verification.

## References

- `references/bitwarden-roundtrip-migration.md` — safe Bitwarden↔Proton reconciliation, trash/alias semantics, and passkey-portability research.
- `references/passkey-canary-and-secure-handoff.md` — disposable one-entry migration test, Proton-native passkey validation, and AES-protected delivery using `pass-cli run` secret injection.
- `references/native-export-schema.md` — commit-pinned Proton native ZIP/JSON schema, field paths, timestamp and vault behavior, opaque passkey format, attachment naming, and import-validation pitfalls.
- `references/proton-drive-public-share-retrieval.md` — secure public-share export download workflow and current browser-automation compatibility fixes.
- See the `himalaya` skill's `references/proton-pass-agent-wrapper-for-himalaya.md` for a concrete, production example of a dedicated bash wrapper that drives the agent (with REASON) to supply the Proton Bridge relay credential to himalaya's `auth.cmd` in headless/cron runs. The wrapper follows all the security and REASON discipline documented here.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, never record credentials or secret values, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
