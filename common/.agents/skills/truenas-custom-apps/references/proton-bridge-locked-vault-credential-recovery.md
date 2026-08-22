# Proton Bridge relay credential recovery from a locked initial-sync vault

Use this only when Proton Bridge has already added the account, `info 0` says the user is **currently locked** during first sync, and the user explicitly needs the generated Bridge relay/app password before sync finishes. For routine automation, waiting for `A sync has finished for <user>` and using `info 0` remains simpler.

## Key finding

The CLI lock is a frontend presentation guard, not evidence that the relay credential has not been generated. In Bridge v3, `showAccountInfo` returns early for `bridge.Locked`, while the encrypted vault already contains `UserData.BridgePass`. A direct CLI retry, `pause 0`, or competing temporary Bridge container will not bypass this guard and can restart/compete with synchronization.

## Read-only recovery design

Operate on copies; never modify the live vault or replace Bridge binaries.

1. Keep the TrueNAS-managed Bridge app running so sync continues.
2. Copy the current `vault.enc` to a `0600` temporary file. Bridge writes vault changes via temporary file + atomic rename, so a normal file copy is a coherent snapshot; retry if authentication/decryption detects a race.
3. Retrieve the vault encryption key from Bridge's own GPG-backed `pass` store **inside the container** into a `0600` temporary file. Do not print it. The Docker credential helper stores it beneath `.password-store/docker-credential-helpers/<base64-encoded-server-name>/bridge-vault-key.gpg`; derive/inspect the entry path from the live deployment rather than hard-coding an account-specific identifier.
4. Decode the `pass show` result with standard Base64. It represents the raw vault key.
5. Hash the raw key with SHA-256 and use that digest as the AES key.
6. MessagePack-decode the outer vault structure `{Version, Data}`.
7. AES-GCM-decrypt `Data`: the first `gcm.NonceSize()` bytes are the nonce and the remainder is ciphertext/tag; no additional authenticated data is used.
8. MessagePack-decode the plaintext into a partial structure containing only `Users[].PrimaryEmail`, `Users[].Username`, and `Users[].BridgePass`. Unknown fields can be ignored.
9. Convert raw `BridgePass` bytes with **unpadded URL-safe Base64** (`base64.RawURLEncoding`), matching `pkg/algo.B64RawEncode`. The primary email is the combined-mode client username.
10. Write the username/password to a dedicated secret file only if runtime use is required: parent `0700`, file `0600`. Immediately delete the temporary raw vault key, copied vault, decoder source/binary, and transient credential file.

A minimal standalone Go decoder should import only `github.com/vmihailenco/msgpack/v5` plus the standard library. Importing Bridge's full `internal/vault` package also compiles `pkg/keychain` and may unnecessarily require desktop `libsecret`; this dependency is unrelated to decrypting an already copied vault.

## Disclosure rule

Default behavior remains: never print relay credentials in logs, tool summaries, skills, memory, or general completion reports. If the user **explicitly asks for a copyable generated Bridge app password**, it is acceptable to reveal only that requested relay password once in the direct response, clearly label it as distinct from the Proton account password, and avoid including any Proton login password, TOTP, vault key, token, or account secret. Suggest deleting the chat message after copying. Preserve the credential in a password manager or a root-only temporary local secret according to the user's requested workflow.

## Verification and limitations

- Treat the CLI's `Locked` state as an `info`-display restriction, **not** as a definitive IMAP/SMTP readiness signal. During partial initial sync, an account may first reject authentication as `no such user` and later begin accepting the recovered relay credential while `info 0` still reports locked. Test IMAPS and SMTP authentication directly with the recovered credential; do not infer readiness solely from sync percentage or CLI state.
- Recovery proves the relay credential value but does not itself change account readiness or synchronization state.
- After authentication becomes available, verify both authenticated IMAPS and SMTP STARTTLS, not only TLS handshakes or open ports.
- If decryption fails, do not alter the live vault: refresh both the key and vault snapshot, confirm the running Bridge version/source format, and retry on copies.
- Do not repeatedly stop/restart Bridge merely to run `info 0`; that delays synchronization and adds stale-lock risk.
