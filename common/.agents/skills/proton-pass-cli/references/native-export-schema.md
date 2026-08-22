# Proton Pass native export/import contract

Use this reference when generating, validating, or reconciling a native Proton Pass archive without exposing export contents. Re-check upstream before production use.

## Source checkpoint

Verified against:

- `proton-webclients` commit `b42394a71e7f342a4825c42c083b612ecedd1f27`
- `proton-pass-common` commit `65bb8448a41098686c9305265d2312c79d4dcef8`

Do not inspect user exports unless explicitly authorized. Derive the contract from source and use synthetic fixtures for validation.

## ZIP contract

Unencrypted native archive:

```text
Proton Pass/data.json
Proton Pass/files/<attachment-export-name>
```

Encrypted archives use `Proton Pass/data.pgp`; when both data files exist, the importer prefers `data.pgp`. A standalone `.json` is not dispatched by the normal Proton Pass import provider, so generated native JSON should be wrapped in a `.zip`.

Sources: `packages/pass/lib/export/archive.ts:22-25,70-92`; `packages/pass/lib/import/providers/protonpass/protonpass.zip.reader.ts:20-45`; `packages/pass/lib/import/reader.ts:79-106`.

## JSON field paths

Top level:

```text
userId?                    string; relevant primarily to alias ownership
version                    app version string; use >= 1.18.0
vaults                     Record<string, Vault>
```

Vault:

```text
vaults.<key>.name          string
vaults.<key>.description   string
vaults.<key>.display       { icon?: number, color?: number }
vaults.<key>.items         Item[]
```

Item envelope:

```text
itemId                     string
shareId                    string
state                      1 active | 2 trashed
aliasEmail                 string | null
contentFormatVersion       number; current web value is 8
createTime                 Unix epoch seconds
modifyTime                 Unix epoch seconds
pinned                     boolean
shareCount                 number (may be omitted when undefined)
files                      tokenized attachment basenames[]
data                       deobfuscated item body
```

Common item body:

```text
data.type                  login | note | alias | creditCard | identity | sshKey | wifi | custom
data.metadata.name         string
data.metadata.note         string
data.metadata.itemUuid     string
data.content               type-specific object
data.extraFields           array
data.platformSpecific?     optional Android metadata
```

Extra field shapes:

```json
{"fieldName":"...","type":"text","data":{"content":"..."}}
{"fieldName":"...","type":"hidden","data":{"content":"..."}}
{"fieldName":"...","type":"totp","data":{"totpUri":"..."}}
{"fieldName":"...","type":"timestamp","data":{"timestamp":"YYYY-MM-DD"}}
```

Sources: `packages/pass/lib/export/types.ts:3-14`; `packages/pass/store/selectors/export.ts:51-86`; `packages/pass/types/data/items.ts:69-86`; `packages/pass/types/data/shares.ts:22-26`; `packages/pass/types/crypto/pass-types.ts:28-31,88-104`; `packages/pass/utils/time/epoch.ts:1-7`.

## Login body

```text
data.content.itemEmail             string
data.content.itemUsername          string
data.content.password              string
data.content.totpUri               string
data.content.urls[]                legacy Default-mode duplicate
data.content.autofillUrls[].url     string or pattern, according to mode
data.content.autofillUrls[].mode    integer enum
data.content.passkeys[]             Proton native passkey objects
```

Autofill modes: `0 Default`, `1 Exact`, `2 Never`, `3 StartWith`, `4 Pattern`, `5 RegularExpression`, `6 ExactPath`.

`autofillUrls` is authoritative when non-empty. `urls` should contain only mode-0 entries for old clients. Import sanitizes/deduplicates URL rules and drops malformed URLs, unsupported schemes, unknown modes, and unsafe regexes. Feature flags can degrade advanced modes, so round-trip tests must check every mode.

Versions below `1.18.0` trigger legacy migration from `content.username` to `itemEmail` and clear `itemUsername`.

Sources: `packages/pass/store/selectors/export.ts:20-34`; `packages/pass/lib/import/providers/protonpass/protonpass.json.reader.ts:60-82`; `packages/pass/lib/import/helpers/transformers.ts:50-65`; `packages/pass/types/protobuf/item-v1.static.ts:2-31`.

## Passkey object

```text
keyId                      string
content                    standard Base64 opaque Proton state
 domain                    string
rpId                       string
rpName                     string
userName                   string
userDisplayName            string
userId                     standard Base64 bytes
createTime                 Unix epoch seconds
note                       string
credentialId               standard Base64 bytes
userHandle                 standard Base64 bytes
creationData?              { osName, osVersion, deviceName, appVersion }
```

`content`, `userId`, `credentialId`, and `userHandle` are decoded with `Uint8Array.fromBase64()` before protobuf serialization. `content` is Proton-specific MessagePack: a versioned wrapper (currently version 1) containing serialized COSE/private-key state. Treat a Proton passkey object as opaque and preserve it byte-for-byte. Bitwarden FIDO2 JSON is not a drop-in replacement; conversion requires validated PKCS#8→COSE/MessagePack transformation plus real relying-party authentication.

Sources: `packages/pass/types/protobuf/item-v1.ts:25-101,119-150`; `packages/pass/lib/items/item-proto.transformer.ts:66-75,200-212`; `packages/pass/lib/passkeys/utils.ts:11-17`; `proton-pass-common/src/passkey/passkey_handling.rs:17-27,73-95`.

## What native import preserves

Preserved or consumed:

- `data`
- `createTime` / `modifyTime` in the initial item import request
- active/trashed state
- attachment references
- `aliasEmail` for alias items
- vault grouping and vault name

Ignored/reallocated:

- item `itemId`, `shareId`, `pinned`, `shareCount`, and input `contentFormatVersion`
- original `metadata.itemUuid` (replaced)
- vault key/share identity, description, display icon, and color

Each imported vault gets a new share and an `Imported on <date>` description. The current serializer/protobuf format is used for imported items.

Sources: `packages/pass/lib/import/providers/protonpass/protonpass.json.reader.ts:42-105`; `packages/pass/store/sagas/import/import.saga.ts:44-64,147-180`; `packages/pass/lib/items/item.requests.ts:329-369`.

## Attachment naming and timestamp pitfall

The official exporter uses:

```text
<original-base>.<share/file hash><final extension>
```

The importer does not validate the hash. A generator may use a globally unique token:

```text
item.files[] = "report.<uuid>.pdf"
ZIP entry    = "Proton Pass/files/report.<uuid>.pdf"
```

This restores the visible filename as `report.pdf`. Always inject a token before the final extension; otherwise a dotted basename such as `report.final.pdf` can be restored as `report.pdf`. For extensionless names use a long token (roughly 16+ characters). Use basenames, not full archive paths, and ensure global uniqueness.

Attachments are uploaded and linked after item creation. The link request carries no `CreateTime` or `ModifyTime`, so the final attachment-link revision has backend-controlled modification time. Native import preserves the requested item timestamps initially but cannot guarantee the final `modifyTime` after attachments are linked.

Sources: `packages/pass/lib/file-attachments/helpers.ts:63-90`; `packages/pass/lib/import/helpers/files.ts:8-24`; `packages/pass/hooks/import/useFileImporter.ts:45-120`; `packages/pass/lib/file-attachments/file-attachments.requests.ts:122-188`.

## Validation/import behavior

There is no runtime JSON schema validator: the reader does `JSON.parse(...) as ExportData`. Therefore validate generated archives independently before import.

Recommended synthetic validation:

1. Check exact ZIP paths and that every `item.files[]` resolves to one archive entry after Proton filename sanitization.
2. Require epoch-second integer timestamps; reject millisecond-scale values and impossible ordering locally.
3. Require current login fields and standard Base64 passkey byte fields.
4. Ensure `urls` equals only the mode-0 subset of `autofillUrls`.
5. Ensure unique vault keys, item correlation IDs, and attachment names.
6. Import into disposable vaults and verify counts, timestamps, URL modes, passkeys, and attachment contents.
7. Verify passkeys against their real relying parties; import acceptance is insufficient.

Malformed top-level structures usually fail the whole reader. Invalid item serialization can be caught per item and reported as ignored. API batch failures are reported and processing continues. Missing attachment entries remain ignored. Attachment upload is plan- and size-limited.

Sources: `packages/pass/lib/import/providers/protonpass/protonpass.json.reader.ts:31-35,108-116`; `packages/pass/lib/items/item-proto.transformer.ts:260-347`; `packages/pass/lib/items/item.requests.ts:329-369`; `packages/pass/store/sagas/import/import.saga.ts:161-204`.

## Cross-repository warning

At the pinned revisions, `proton-pass-common/proton-pass-types/proto/item_v1.proto` lacks the newer `autofill_urls` field while the webclient generated schema and native exporter/importer support it. Treat `proton-webclients` as authoritative for native JSON. Use `proton-pass-common` only for internal protobuf/passkey semantics, and always record the inspected commit IDs.
