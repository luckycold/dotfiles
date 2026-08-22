# Secure retrieval of Proton Drive public-share exports

Use this when a user supplies Proton Drive public links for sensitive vault exports and the browser download cannot directly place files on the agent filesystem.

## Security model

A public-share URL contains a fragment key, but a share may also require a separate password. The fragment is not the optional share password. Keep both out of logs, summaries, argv, and process listings where practical.

1. Create a dedicated `0700` working directory before download.
2. Supply the share password through an environment variable or protected file, not a command-line flag.
3. Download with a browser/official SDK path when possible.
4. Immediately set downloaded exports to `0600`.
5. Record size and SHA-256 before parsing, and never print credential values or attachment names unnecessarily.
6. Inspect schemas and aggregate counts first; write detailed title/ID reports only inside the protected directory.

## Browser-automation fallback

The deprecated `pdown` 1.0.5 utility can still be useful as a source-reviewed fallback because it drives Proton's own web client and lets that client decrypt the share. Prefer Proton's official Drive CLI/SDK when it supports the needed public-share workflow.

Current durable compatibility fixes discovered during a 2026 retrieval:

- Accept Base64URL characters in both share ID and fragment: `[A-Za-z0-9_-]`. Older `pdown` regexes accepted only alphanumerics and silently skipped links whose fragment began with `-` or contained `_`.
- Current single-file UI uses a two-stage download menu:
  1. click `button[data-testid=dropdown-download-button]`
  2. click `button[data-testid=download-button]`
- A password selector can exist before the decrypted file view is ready. Only require a password when the page actually presents the protected-share form; do not infer protection from any generic `input[type=password]` found during initial app loading.
- Transfer-manager DOM selectors are not authoritative completion signals for small files. A monitor may report `Download did not start` after Chromium has already written the file. Always inspect the target directory and verify file size/hash before retrying or declaring failure.

## Verification and cleanup

- Confirm expected file types without extracting secret values.
- For Proton native ZIPs, enumerate member paths only; expected data is typically under `Proton Pass/data.json`.
- For Bitwarden JSON, report only aggregate item/type/passkey/TOTP/custom-field counts and timestamp ranges.
- Keep source files immutable. Generate reports and merged archives as separate `0600` artifacts.
- After successful migration and rollback-period expiry, remove plaintext working copies using the user's approved secure-cleanup policy; remember that overwrite-based shredding is unreliable on SSDs and copy-on-write filesystems.
