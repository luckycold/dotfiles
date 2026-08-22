# Bitwarden ↔ Proton Pass round-trip migration

Use this reference when reconciling a Proton Pass vault that was previously imported into Bitwarden and later needs to return to Proton Pass without losing newer edits, attachments, or passkeys.

## Durable findings

- Do **not** import a Bitwarden export directly over a populated Proton Pass vault when deduplication is required. Proton import creates new items rather than matching and updating existing records, so this increases duplicates.
- Bitwarden plaintext JSON exports carry item-level `revisionDate` / `creationDate`; Proton native JSON exports carry epoch `modifyTime` / `createTime`.
- Bitwarden JSON exports include stored passkeys. ZIP-with-attachments includes `data.json` plus `attachments/<item UUID>/...`; obtain both plaintext JSON and ZIP-with-attachments when completeness matters.
- Proton's third-party login importer currently initializes `passkeys: []`; its Bitwarden reader does not consume `login.fido2Credentials`.
- Proton's native Proton Pass JSON reader preserves complete native login content, including an existing `passkeys` array. However, the passkey byte fields must be standard Base64 and `content` is Proton-specific versioned MessagePack/COSE state, so Bitwarden FIDO2 JSON is not directly importable.
- Native import preserves supplied item timestamps in the initial batch request, but attachment upload/linking happens later and the link API has no timestamp override; the final item `modifyTime` may therefore be backend-controlled.
- Native import preserves vault grouping/name but allocates new vault and item IDs; it does not restore vault description/display, item pin state, share counts, or original UUIDs.
- Native alias import is special: existing aliases are skipped, and alias recreation requires the exported `userId` to match the importing Proton account. For a same-account clean migration, preserve the existing alias vault or omit aliases from the operational import archive; do not assume aliases will be recreated into new vaults.
- Treat Proton `state: 2` items as timestamped tombstones during reconciliation. A matcher that drops trash before matching can accidentally resurrect a Bitwarden copy of something deleted later in Proton.
- See `native-export-schema.md` for the exact current field paths and source references.
- Bitwarden CXP export only helps when the destination app supports FIDO Credential Exchange Protocol. Do not assume Proton supports CXP without checking current docs/source.

## Safe reconciliation workflow

1. Create immutable safety backups first:
   - Bitwarden: plaintext JSON, ZIP with attachments, and separate organization exports where applicable.
   - Proton Pass: encrypted PGP ZIP for backup and unencrypted ZIP as the local working input.
2. Never transmit exports through chat. Process locally in an encrypted/restricted directory; reports must omit passwords, TOTP seeds, SSH keys, IDs, and passkey key material.
3. Canonicalize records before comparing. Prefer conservative login keys based on normalized URL/RP ID plus username/email; retain host ports for self-hosted services. Use title+username only when no URL/RP ID exists. Fuzzy matches are review-only. Union-find matching across multiple URLs can create large bridge groups; route unusually large or many-to-many groups to review rather than auto-collapsing them.
4. Include active and trashed Proton items in the matching pass. If a newer Proton tombstone matches an older live Bitwarden copy, keep the deletion; if Bitwarden was genuinely revised later, flag it as a possible resurrection.
5. If canonical content is identical, keep the Proton-native item to retain Proton-specific metadata and union passkeys/attachments. This also avoids over-trusting timestamps that were reset during a prior cross-manager import.
6. If content differs, compare Bitwarden `revisionDate` to Proton `modifyTime`. Use the newer whole item as the base, but union passkeys/attachments and preserve non-conflicting unique fields where possible.
7. Never silently discard an older conflicting record. Put ambiguous or losing versions in a Migration Review vault and produce a redacted local report.
8. Deduplicate passkeys by relying-party ID plus credential ID, never by title alone.
9. For same-account migration, generate an operational archive without aliases or leave the existing alias vault in place; separately retain a full native backup containing aliases.
10. Produce a clean native Proton archive and import it into new/test vaults. Do not wipe either source until counts, passwords, TOTP, attachments, and every migrated passkey have been verified.

## Passkey conversion notes

Typical Bitwarden `fido2Credentials` contain credential ID, RP ID, user handle, username/display name, counter, creation date, and a base64url PKCS#8 P-256 private key. Proton serializes equivalent COSE key material into a versioned MessagePack wrapper and stores it in the native passkey object.

### Exact v1 encoding observed at the pinned commits

- `keyId`: credential ID as Base64URL without padding.
- `credentialId`: the same credential ID bytes as standard Base64.
- `userId` and `userHandle`: user-handle bytes as standard Base64.
- `content`: standard Base64 of a MessagePack wrapper `{"c": [<inner bytes>], "v": 1}`.
- Inner MessagePack keys: `key`, `cid`, `rid`, `uhd`, `cnt`, `ext`.
- `key.kty = {"t":"assign","c":"EC2"}` and `key.alg = {"t":"assign","c":"ES256"}`.
- COSE parameters are pairs keyed by integer labels: `-1` curve P-256, `-2` X, `-3` Y, `-4` private scalar D. Proton serializes these byte values as integer arrays, not MessagePack binary blobs.
- The curve value is Proton's serialized i128 wrapper for COSE curve label `1`: `{"t":"int","c":{"inner":[1,0,...,0]}}` with 16 little-endian bytes.
- `ext` currently contains `{"hmac_secret": null}`. Proton's stored structure has no Bitwarden `discoverable` field, so flag preservation cannot be assumed even when the private credential remains usable.

Before emitting an archive, decode the generated object and compare credential ID, RP ID, user handle, D, X, and Y to the source. Then sign with the source key and verify using the reconstructed key. Avoid printing even partial private-key arrays during schema introspection; emit only field names, types, and lengths.

A defensible converter must:

1. Decode and validate the Bitwarden PKCS#8 key.
2. Derive P-256 public coordinates and verify consistency.
3. Encode the corresponding Proton COSE/MessagePack structure with the same credential ID, RP ID, user handle, and counter.
4. Decode its own output independently.
5. Perform a local sign/verify round trip.
6. Reject unsupported algorithms or malformed fields into a manual re-registration report.
7. Test imported copies against the actual sites while Bitwarden remains intact.

Do not claim passkey migration succeeded based only on archive generation or import acceptance; a real authentication against the relying party is the final verification.

### Native Android-link pitfall

A generated native login can be silently ignored while its destination vault is still created, making the import appear as a blank vault. One confirmed cause is malformed `data.platformSpecific.android.allowedApps`: every entry must supply non-empty string `packageName` and `appName` fields plus a non-empty string array `hashes`. For a Bitwarden `androidapp://<package>` URI, mirror Proton's official importer and emit:

```json
{"packageName":"<package>","appName":"<package>","hashes":["<package>"]}
```

Do not emit `appName: null` or omit `hashes`. Add a regression validator for this shape before importing any generated archive. The official mapping is in `packages/pass/lib/import/helpers/transformers.ts` (`importLoginItem`, Android `allowedApps`).

### Passkey domain-selection pitfall

For a converted passkey, the outer Proton `passkey.domain` must match the credential RP ID, not merely the first URL on the parent login. Proton's autofill selector parses `passkey.domain` and requires it to equal the current browser domain before considering the credential ID (`packages/pass/store/selectors/autofill.ts`). Legacy URL sets can contain a different hostname (for example, an old brand domain) even when the registered credential RP ID is the current domain. If `domain` differs from `rpId`, Proton may display the passkey in the item but never offer that credential to the relying party.

Validate all three values together before import:

- outer `domain == rpId` after hostname normalization;
- inner serialized passkey RP ID equals outer `rpId`;
- outer `keyId` decodes to the same bytes as `credentialId`.

### Bitwarden credential-ID encoding pitfall

Mirror Bitwarden's `parseCredentialId` exactly. A Bitwarden `credentialId` without the `b64.` prefix is a textual UUID and must be converted to its raw 16 RFC-4122 bytes (hex octets in network order). Only a value prefixed with `b64.` is base64url-decoded. Do not pass an ordinary hyphenated UUID to a permissive base64url decoder: the hyphens are accepted as URL-safe alphabet characters and silently produce 27 incorrect bytes. Proton can still display and offer that discoverable credential, but the relying party cannot find the registered 16-byte credential ID and rejects the assertion.

Add a regression test that follows Bitwarden's source logic (`credential-id-utils.ts` → `guid-utils.ts`) and checks the exact expected byte length/value. The canary that exposed this bug expected 16 bytes but the incorrect converter emitted 27.

### Signature-counter semantic pitfall

Do not translate a Bitwarden counter value of `0` to Proton inner `cnt = 0`. Current Bitwarden authentication logic treats zero as **counter unsupported** and leaves every assertion at zero; Proton's `passkey-rs` treats `Some(0)` as an enabled counter, increments it, and emits `1` on the first assertion. Proton-native passkeys encode counter unsupported as `cnt = null` (`None`). Map Bitwarden zero to Proton null, while preserving a genuinely positive source counter only after assessing relying-party rollback/clone-detection risk.

Regression-check this separately from key-material validation. Local P-256 sign/verify cannot reveal an authenticator-data counter mismatch. For a zero-counter Bitwarden credential, decode the generated MessagePack and require `inner.cnt is null` before real-site testing.

For the proven one-entry canary workflow—including safe candidate selection, full-login mapping, AES-256 outer delivery with a Proton Pass-injected password, hash verification, and user import instructions—see `passkey-canary-and-secure-handoff.md`.

### URL-rule and raw-TOTP preservation pitfalls

Do not flatten Bitwarden URI match rules when generating native Proton login content. At the pinned webclient revision, map Bitwarden modes to Proton modes as follows: BaseDomain/default `0 -> 0`, Host `1 -> 1` (Exact host), StartsWith `2 -> 3`, Exact `3 -> 6` (ExactPath), RegularExpression `4 -> 5`, and Never `5 -> 2`. Populate legacy `urls` only with mode-0 entries; keep the complete rules in `autofillUrls`. Regression-check every source/output URL and mode pair.

For a raw Bitwarden TOTP secret, remove **all** embedded whitespace with a `\\s+` rule before wrapping it as an `otpauth://totp/...` URI. Removing ordinary spaces alone misses embedded newlines present in some exports and percent-encodes them into an invalid secret. Preserve an existing `otpauth://` URI exactly, and independently compare its secret/algorithm/digits/period or generated code. Never print TOTP values during validation.

## Source checkpoints from the 2026 research pass

- Proton support: `https://proton.me/support/pass-import-bitwarden`
- Proton export/import: `https://proton.me/support/pass-export`
- Bitwarden export docs: `https://bitwarden.com/help/export-your-data/`
- Proton web source commit checked: `b42394a71e7f342a4825c42c083b612ecedd1f27` (2026-08-07)
  - `packages/pass/lib/import/helpers/transformers.ts`: third-party login import initializes an empty passkey list.
  - `packages/pass/lib/import/providers/bitwarden/bitwarden.reader.ts`: Bitwarden passkeys are not read.
  - `packages/pass/lib/import/providers/protonpass/protonpass.json.reader.ts`: native item content is preserved on import.
- Proton passkey serialization source checked: `protonpass/proton-pass-common` commit `65bb8448a41098686c9305265d2312c79d4dcef8`.

Re-check current upstream behavior before a real migration; implementation details can change.