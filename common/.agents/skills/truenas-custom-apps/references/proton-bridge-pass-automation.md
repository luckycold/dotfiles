# Proton Bridge + Proton Pass automation on TrueNAS

Use this for secure one-time Bridge login and generated relay-credential handling. For standard public ports, TLS, DNS, and NAT, continue with `proton-bridge-public-mail-client-exposure.md`.

## Secret-injection pattern

Set a specific reason on every Pass operation:

```bash
export PROTON_PASS_AGENT_REASON="Initialize Proton Mail Bridge on TrueNAS and store its generated relay credential"
```

Keep env files reference-only and mode `0600`:

```dotenv
PROTON_USER=pass://<share-id>/<item-id>/username
PROTON_PASS=pass://<share-id>/<item-id>/password
PROTON_TOTP=pass://<share-id>/<item-id>/totp
```

Run a PTY helper through the agent:

```bash
proton-pass-agent run --env-file bridge-init.env -- ./bridge-init-pty.py
```

This can inject a masked login password even when `item view --output json` does not reveal it. Never print the resolved environment, command arguments containing secrets, or raw PTY transcript.

## Correct Bridge prompt sequence

A robust helper must handle prompts in this order:

1. interactive shell / `>>>`
2. `login`
3. username
4. Proton account password
5. optional security-key question — answer `no`
6. `Two factor code:` — send a fresh numeric TOTP
7. success line matching `was added successfully`

The security-key question contains the words “Two-factor authentication.” Do not treat that as the TOTP prompt. Sending a TOTP URI/code there causes Bridge to keep asking yes/no and never reaches login completion.

A `/totp` Pass reference can resolve to an `otpauth://` URI. Generate the numeric TOTP in memory from its `secret`, `digits`, and `period`; do not send or log the URI itself. Generate as late as possible so a 30-second code does not expire during container startup.

The success line includes the account name—typically `Account <name> was added successfully.` A matcher for only `account was added` will miss it and can leave a successful temporary CLI running until timeout.

## Container/vault handling

For `shenxn/protonmail-bridge`, persist the container home at `/root` so Bridge cache, config, GPG/pass state, and vault survive recreation:

```bash
docker run --rm -it \
  --entrypoint protonmail-bridge \
  -v /mnt/Apps/Applications/proton-bridge/data:/root \
  <bridge-image> --cli
```

Use the image's `init` entrypoint only when GPG/pass truly need initial setup. Once the persistent home is initialized, invoke `protonmail-bridge --cli` directly; repeatedly running the init entrypoint can create unnecessary GPG keys.

Stop the TrueNAS-managed app before temporary CLI access. If a timeout leaves a temporary container alive, identify and remove that container before deleting `bridge-v3.lock`. Never delete the lock while another Bridge process is active.

## Generated relay credentials

The Bridge-generated relay username/password are local to the Bridge vault and are not the Proton account password. Reinitializing or re-adding an account can invalidate an older Pass `bridge` field.

After login and initial sync unlock:

1. Start one temporary CLI while the managed app is stopped.
2. Run `info 0` and parse the relay username/password without printing them.
3. Update the relevant Pass field/item.
4. Remove any temporary credential file immediately after a successful Pass update.
5. Start the managed app.
6. Verify authenticated IMAP folder listing and SMTP authentication.

During initial sync, `info 0` may say the user is locked. Let the managed app continue the sync rather than repeatedly launching temporary CLI instances. TLS-only probes can succeed before the account is usable; authentication is the deciding check.

When locating credentials, filter Pass to login items:

```bash
proton-pass-agent item list Main --filter-type login --output json
```

A recursive title search across all item types can select an email alias whose title resembles a service login. Alias items do not expose `username` or `password` fields.

## Verification

- Persistent home contains vault/keychain state, not merely empty directories.
- Managed app is `RUNNING` and only one Bridge process owns the vault.
- Recent logs show the account connected/syncing or synchronized.
- Protocol CAPABILITY/EHLO checks succeed.
- Authenticated IMAP succeeds using the newly captured relay credential.
- No Proton password, TOTP URI/seed/code, or Bridge password appears in logs, skills, memory, or summaries.