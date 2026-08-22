# Single-entry passkey canary and secure handoff

Use this procedure before a bulk Bitwarden → Proton Pass passkey migration. It proves the converter, native archive shape, import path, and real relying-party behavior with one credential while both source managers remain intact.

## Canary selection

1. Start from the redacted reconciliation report, not from a random first record.
2. Prefer a **Bitwarden-only**, active login with exactly one `fido2Credentials` entry. This avoids overwriting or duplicating an existing Proton credential during the canary.
3. Avoid ambiguous many-to-many groups, trashed/tombstoned matches, and records carrying attachments.
4. Preserve the whole login in the test item—title, username/email, password, URLs and match modes, TOTP, notes, and custom fields—not only the passkey.
5. Put it in a dedicated vault such as `Passkey Migration Test` so cleanup is obvious.

## Native Proton test archive

Generate an unencrypted inner ZIP with exactly:

```text
Proton Pass/data.json
```

Use current native fields (`contentFormatVersion: 8`, epoch-second timestamps, active `state: 1`, `files: []`, and current login fields). Include one vault, one login, and one converted Proton-native passkey. Keep the inner ZIP byte-for-byte unchanged after validation; it is the file Proton Pass should import.

For each converted passkey, independently verify:

- Bitwarden PKCS#8 key is ECDSA/P-256.
- Credential ID, RP ID, user handle, private scalar D, and public X/Y survive encode/decode.
- A signature made with the source private key verifies with the reconstructed public key.
- `content`, `credentialId`, `userId`, and `userHandle` are valid standard Base64 where Proton expects it.
- The wrapper and inner MessagePack keys match the pinned Proton schema.
- Login username/password parity and ZIP CRC/path checks pass.

Compute and retain the SHA-256 of the inner ZIP. Import acceptance is not final proof: authenticate against the real relying party in a separate/private browser session while keeping Bitwarden and an existing logged-in session available.

## CLI/import limitation checkpoint

At Proton Pass CLI 2.1.0, `item create login --get-template` exposes title, username/email, password, TOTP, and URLs but no native passkey field. A viewer-scoped agent also cannot write. Re-check current CLI help each time, but when passkeys are still absent, use a native Proton ZIP and the Proton Pass import UI rather than inventing a CLI field or broadening a viewer token.

Do not bootstrap a broad owner session using credentials readable by the viewer agent merely to bypass its role. Ask the user to perform/authorize the import or use a separately authorized session.

## Password-protected delivery

Never send the plaintext inner archive through Telegram or another ordinary chat channel. If the user explicitly requests a downloadable protected file, wrap the inner native ZIP in an **outer WinZip AES-256 ZIP**. The user extracts the outer ZIP first, then imports the unchanged inner ZIP into Proton Pass.

Preferred secret-injection pattern:

1. Locate the exact password item by vault/title using metadata-only `pass-cli item list` calls and a short `PROTON_PASS_AGENT_REASON`.
2. Write a temporary mode-`0600` dotenv file containing only a secret reference:
   ```dotenv
   ARCHIVE_PASSWORD=pass://SHARE_ID/ITEM_ID/password
   ```
3. Run an encryptor through:
   ```bash
   proton-pass-agent run --env-file /tmp/archive.env -- python encrypt.py
   ```
4. The encryptor reads `ARCHIVE_PASSWORD` from its environment. Never place the resolved password in argv, logs, tool output, a generated command, or model context.
5. With `pyzipper`, use `WZ_AES`, `nbits=256`, and `ZIP_DEFLATED`.
6. Reopen with the injected password, recover the inner bytes, and compare their SHA-256 to the original.
7. Verify that an intentionally wrong password is rejected.
8. Set the outer ZIP to `0600`, hash it, confirm the file signature reports AES encryption, and remove the temporary dotenv reference file.

The outer archive should contain only the already-validated inner import ZIP. Warn that some stock extractors do not support WinZip AES; 7-Zip, PeaZip, WinRAR, or Keka generally do.

Do not send the archive password in the same channel as the archive. A password already known to the user and retrieved through Proton Pass is suitable. One-time link passwords, archive passwords, and share fragments are credentials: never save them to persistent memory. If one is accidentally persisted, delete that memory immediately and tell the user.

## Verification and cleanup

After the user imports the inner ZIP:

1. Confirm the test vault contains exactly one login and one passkey.
2. Confirm the RP ID and visible metadata are correct without exposing secret fields.
3. Test real-site authentication in a separate/private session.
4. Keep the Bitwarden source until the real authentication succeeds.
5. If the test fails, remove only the disposable Proton test vault and retain both source exports plus hashes.
6. Delete protected delivery copies only after the user confirms successful import and no longer needs them.
