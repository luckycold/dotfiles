# Proton Mail Bridge on TrueNAS: standard mail-client exposure

Use this reference when a TrueNAS-managed `shenxn/protonmail-bridge` deployment must serve ordinary mail clients on standard ports rather than remain localhost-only.

## Target architecture

The image's entrypoint uses `socat` in front of Bridge:

- container `143` → Bridge IMAP `127.0.0.1:1143`
- container `25` → Bridge SMTP `127.0.0.1:1025`

For conventional clients, publish:

```yaml
ports:
  - "0.0.0.0:993:143/tcp"   # IMAPS
  - "0.0.0.0:587:25/tcp"    # SMTP submission + STARTTLS
```

Optional localhost compatibility bindings can coexist:

```yaml
  - "127.0.0.1:1143:143/tcp"
  - "127.0.0.1:1025:25/tcp"
```

Set Bridge IMAP security to **SSL** for port 993. Leave SMTP security as **STARTTLS** for port 587. Do not raw-forward port 993 to a STARTTLS-only IMAP listener; implicit TLS and STARTTLS are different wire protocols.

## One-time account initialization

Stop the managed app before opening another Bridge CLI against the same data volume. Only one Bridge instance may own the vault.

Prefer a derivative image that contains required runtime libraries rather than installing packages into a disposable running container. Mount the persistent Bridge home at `/root` for this image; the vault/keychain/cache live under that home.

A robust PTY automation sequence is:

1. Wait for the Bridge interactive-shell banner or `>>>` prompt.
2. Send `login`.
3. Supply the Proton username at the username prompt.
4. Supply the Proton account password at the password prompt.
5. Bridge may ask: `Do you want to use a security key for Two-factor authentication? yes/no:`. Answer `no` before sending any TOTP.
6. At the separate `Two factor code:` prompt, generate and send a fresh numeric TOTP.
7. Treat a line matching `Account .* was added successfully` or simply `was added successfully` as success; the username appears between `Account` and `was added`, so matching only `account was added` misses it.
8. Exit the temporary CLI and start the managed app so its initial sync can continue.

### Proton Pass TOTP detail

A Proton Pass secret reference ending in `/totp` may resolve to the full `otpauth://totp/...` URI rather than a six-digit code. Never type that URI into Bridge. Parse the URI's `secret`, `digits`, and `period`, generate the current TOTP in memory, and send only the numeric code at the actual `Two factor code:` prompt. Never print or persist the URI, seed, code, Proton password, or generated Bridge password.

Use `proton-pass-agent run --env-file <references-only.env> -- <pty-helper>` so credentials reach the helper through environment variables without literal secrets in the env file or shell history. Set `PROTON_PASS_AGENT_REASON` for every operation.

## Generated relay credential lifecycle

Bridge creates a local relay username/password after account login. It is distinct from the Proton account password and may change when the Bridge vault is rebuilt or the account is re-added. Therefore:

- Never assume an older Pass custom field such as `bridge` still matches a newly initialized vault.
- Retrieve `info 0` only from a single stopped/temporary CLI instance, without printing its password into tool output.
- Store or replace the generated relay password in Proton Pass, then inject it into clients at runtime.
- Verify authentication; a successful TLS handshake does not prove the saved relay credential is current.

A viewer-scoped Proton Pass agent cannot create/update items. Do not silently bypass that boundary by using Proton account credentials to establish an owner session. If the generated relay credential must be used before a human can save it in Pass, keep it in a dedicated root-only local JSON/secret file (`0700` parent, `0600` file), point client auth helpers at that file without logging it, and explicitly leave one manual “copy into Proton Pass” step. Remove the local copy after Pass storage and runtime injection are verified.

During the first mailbox synchronization, `info 0` can report that the user is locked. Normally let the managed app continue syncing and retry after unlock; repeatedly starting temporary CLI containers restarts/competes with synchronization. If the user explicitly needs the already-generated relay/app password immediately, do **not** keep interrupting sync to retry `info 0`: the lock is a CLI frontend guard, and the credential can be recovered read-only from copies of `vault.enc` and Bridge's GPG-backed vault key using `references/proton-bridge-locked-vault-credential-recovery.md`. A partially completed sync can also produce transient Gluon update messages. CLI lock state and protocol readiness are not identical: authenticated IMAP/SMTP may begin working while `info 0` remains locked, so test the protocols directly with the recovered credential instead of waiting solely on a percentage or CLI state.

For a long initial sync, prefer a durable one-shot finalizer over keeping an interactive session open: monitor for the exact CLI event `A sync has finished for <user>`, then stop the managed app, capture `info 0`, restart through TrueNAS middleware, run authenticated IMAP/SMTP tests, and clean transient containers/files. The finalizer must refuse to stop Bridge while only percentage progress is present. A one-shot scheduled job may invoke it later, but its prompt must be self-contained and must not recursively schedule jobs.

When searching Proton Pass, use `item list <vault> --filter-type login`. Recursive title searches across every item type can mistake email-alias items for login credentials; aliases do not have `username`/`password` fields and secret-reference resolution correctly fails.

## Certificate and protocol configuration

Import a publicly trusted certificate through the Bridge CLI while the managed app is stopped:

```text
cert import
/path/to/fullchain-or-cert.pem
/path/to/private-key.pem
change imap-security
yes
```

Bridge persists certificate **paths**, so mount the certificate directory read-only at the same container path in both the temporary configuration container and the managed app. Before import, verify:

- certificate SAN covers the chosen mail hostname;
- certificate is currently valid;
- certificate and private key public keys match;
- mounted files are readable by Bridge.

After restart, verify both modes:

```bash
openssl s_client -connect mail.example.com:993 -servername mail.example.com -verify_hostname mail.example.com
openssl s_client -starttls smtp -connect mail.example.com:587 -servername mail.example.com -verify_hostname mail.example.com
```

For IMAP, send `CAPABILITY` and `LOGOUT`. For SMTP, send `EHLO` and confirm `AUTH LOGIN PLAIN` after STARTTLS. Then perform an authenticated folder/list test with the generated Bridge credential.

## Public DNS and routing

Mail protocols require direct TCP reachability. A Cloudflare orange-cloud/proxied A record normally cannot proxy IMAPS `993` or SMTP submission `587`; configure the mail hostname as **DNS-only** and point it at the current WAN address unless Cloudflare Spectrum or another mail-capable TCP proxy is deliberately in use.

If the zone is covered by a proxied wildcard, create an **exact** DNS-only A record for the mail hostname; the exact record overrides the wildcard without changing unrelated web routes. On TrueNAS systems already issuing a wildcard via Cloudflare DNS challenge, `acme.dns.authenticator.query` may contain a scoped Cloudflare `api_token` or global-key/email tuple. Reuse that credential in memory on the NAS for the DNS mutation instead of exporting it or searching unrelated Pass login/alias records. Inspect only authenticator names/attribute keys in logs, never credential values, and verify the resulting record through multiple public resolvers.

Create router/NAT rules:

- WAN TCP `993` → TrueNAS TCP `993`
- WAN TCP `587` → TrueNAS TCP `587`

Confirm host listeners, firewall allowance, NAT rules, public DNS, and ISP reachability independently. Test from a genuinely external network; hairpin NAT or split DNS proves only the LAN path.

For `check-host.net/check-tcp`, a successful result can be shaped as `[{"address":"<ip>","time":<seconds>}]` rather than containing the literal word `Connected`. Treat a resolved address plus numeric connection time as success; do not mislabel every node as failed by searching only for status words. Require several geographically independent nodes on each port, then still run protocol-aware TLS/authentication checks separately.

## Client troubleshooting: separate server health from client configuration

When one client fails, prove the layers independently before changing Bridge:

1. Use a certificate-verifying IMAP client with the current relay credential against `mail.example.com:993` and require login plus `LIST` success.
2. Use a certificate-verifying SMTP client against `mail.example.com:587`, issue STARTTLS, and require authenticated login.
3. Only after both direct tests pass, inspect the failing client's exact username, password source, server, ports, and protection modes.

A common migration failure is **stale client credential plumbing**. If direct authentication with the newly recovered relay credential succeeds but Himalaya reports `no such user`, inspect all four settings: `backend.login`, `message.send.backend.login`, `backend.auth.cmd`, and `message.send.backend.auth.cmd`. Both auth commands may still call an old Proton Pass custom field even after the visible login fields were updated. Point them at the approved current secret source, keep the helper output password-only, and rerun `himalaya folder list --output json`; do not blame Bridge merely because one wrapper is stale.

For Spark and similar mobile clients, force manual/private-IMAP setup and use:

- IMAP server: mail hostname, port `993`, **SSL/TLS** (implicit TLS)
- SMTP server: same hostname, port `587`, **STARTTLS**, SMTP authentication required
- Username: the exact Bridge client username on both sides
- Password: the generated Bridge relay/app password on both sides

Do not select implicit SSL/TLS for SMTP port 587. If Bridge logs show TCP connections or `socat ... Connection reset by peer` but no IMAP/SMTP authentication command, suspect a client-side protection/port mismatch or an aborted TLS probe. Explicit `Incorrect login credentials` / `no such user` entries indicate that authentication was actually attempted. Some mobile clients cache failed autodiscovery settings; delete the incomplete account and re-add it manually after correcting Advanced/Additional Settings.

## Spark/MailCore evidence ladder

Do not stop at a generic Spark/MailCore message such as `Unable to authenticate with the current session's credentials`. That text can represent several different layers. Also do not keep asserting DNS caching after a fresh hostname or live packet path disproves it; accept the correction and move to wire evidence.

Use this order:

1. **Prove every server-side auth mechanism independently.** Test IMAP `LOGIN` and `AUTHENTICATE PLAIN`, plus SMTP `AUTH PLAIN` and `AUTH LOGIN`, using a certificate-verifying client and the current Bridge credential. A generic `smtplib.login()` success alone does not prove each mechanism works.
2. **Capture one user-triggered retry.** On the mail host, run a bounded packet capture such as:
   ```bash
   timeout 180 tcpdump -i any -nn -s0 -w /tmp/mobile-mail.pcap 'tcp port 993 or tcp port 587'
   ```
   Tell the user exactly when capture is ready and ask for one retry. Stop it immediately afterward. A Linux `-i any` capture may contain interface duplicates; deduplicate by IPs, ports, TCP sequence/ack, flags, and payload before counting flows.
3. **Read the actual path from SYN packets.** This can expose split-DNS/rewrites or a secondary host IP even when public DNS is correct. Do not infer the client's destination from the public record.
4. **Reassemble the SMTP sequence.** For port 587, distinguish greeting → `EHLO` → `STARTTLS` → TLS handshake → encrypted post-TLS commands. `socat ... Connection reset by peer` alone does not prove failure occurred before authentication. TLS 1.3 application records remain opaque without client session keys; packet sizes and resets can establish stage, but not the submitted password.
5. **Correlate with every Bridge log channel at the exact retry timestamp.** Bridge may log only a masked email plus a short hash. Compute SHA-256 prefixes for candidate usernames locally to distinguish full address from local part; do not hard-code account-specific prefixes into documentation. Search all current Bridge logs, not only container stdout or one `_bri_` file.
6. **Do not overclaim from encrypted packets.** Seeing encrypted client records followed by a server response establishes that the session progressed beyond STARTTLS, but cannot prove which username/password bytes were sent. A masked field showing the expected character count also proves length only, not content.

If direct authentication passes but the mobile client still fails, do not intercept or compare the client's submitted credential. Re-enter the authoritative Bridge credential directly in the client, verify the supported username form, and continue diagnosis from ordinary server logs and protocol behavior.

## Durable maintenance pattern

For a public Bridge deployment, leave these mechanisms after one-time setup:

- Keep the managed app in the TrueNAS UI with `restart: unless-stopped`, a persistent `/root` bind, and certificate files mounted read-only.
- Store a sanitized runbook, Dockerfile, and DNS helper under the snapshotted application path (for Luke's deployment: `/mnt/Apps/Applications/proton-bridge/`). Do not leave the only build recipe in `/tmp` or an agent scratch directory.
- Use the existing TrueNAS ACME/Traefik certificate-sync task as the single certificate path. When the mounted Bridge certificate/key actually change, restart the TrueNAS-managed app once so Bridge reloads them. Do not add a competing ACME client.
- Keep exact mail A records DNS-only. If the WAN address is dynamic, use a TrueNAS UI-visible cron task that reads the existing Cloudflare ACME authenticator at runtime and updates only the intended records; never embed the token in the updater.
- Run a silent-on-success watchdog that checks public DNS, trusted certificate lifetime, authenticated IMAP/LIST, authenticated SMTP after STARTTLS, and local credential-file permissions. Alert on state transitions rather than every healthy run.
- Treat Proton as the authoritative mailbox store. Bridge local data is vault/session configuration, indexes, and cache—not a required backup workload. If it is lost, rebuild Bridge, sign in, resynchronize from Proton, and update clients with the newly generated relay credential. A broad Apps snapshot may incidentally include it, but do not create or require a dedicated Bridge backup.
- Preserve the derivative Dockerfile and use a new explicit local image tag for each intentional update. Do not rebuild an old version tag from a moving `latest` base or delete the previous working image before verification.
- Remove PTY login helpers, temporary vault copies/keys, packet captures, API env files, one-shot finalizers, and temporary containers after successful setup. Keep only sanitized recovery instructions and audited runtime helpers.

If the Bridge vault/account is rebuilt, the relay credential can change. Update the protected runtime secret atomically, save the new relay credential in the human password manager, update both incoming and outgoing clients, and rerun authenticated protocol checks.

## Initial-sync monitoring and finalizers

Long initial syncs routinely outlast a fixed `for i in $(seq 1 N)` monitor. A monitor exiting nonzero at a percentage does not mean Bridge failed. Before alerting:

- Check `app.query`, container state, restart count, and current sync evidence.
- Prefer an indefinite monitor with an explicit external cancellation path, or a durable scheduled finalizer, rather than a guessed fixed iteration count.
- If a one-shot finalizer's `next_run_at` is already in the past but `last_run_at` is still empty, move it to a fresh future window and verify the new schedule instead of assuming it ran.
- Keep the finalizer idempotent: it must refuse to interrupt Bridge until the exact sync-finished event is present, and must re-verify the managed app plus authenticated protocols afterward.

## Cleanup and failure handling

PTY/SSH timeouts can leave temporary `docker run --rm -it` containers alive. Before declaring a Bridge lock stale:

1. List all containers using the Bridge image.
2. Preserve the TrueNAS-managed container.
3. Remove only identified temporary containers.
4. Confirm no Bridge process owns the vault.
5. Remove the stale `bridge-v3.lock` only after those checks.
6. Start the managed app and verify protocol listeners again.

Do not report public completion until all of these pass: managed app running, correct Docker publishes, valid TLS/hostname checks, current relay credential authentication, DNS-only public record, router forwards, and external-network probes.