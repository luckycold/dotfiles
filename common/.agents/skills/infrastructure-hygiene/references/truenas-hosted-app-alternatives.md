# TrueNAS user-facing apps: hosted-alternative research

Use this reference when Luke is considering retiring a self-hosted personal/productivity app in favor of a hosted service. This is a **research method plus an August 2026 market snapshot**, not a permanent price list; re-check official pages before quoting.

## Live portfolio inventory before research

For whole-server reviews, inspect the NAS read-only before suggesting subscriptions. Reduce middleware output remotely instead of returning the enormous full `app.query` payload:

```bash
ssh -o BatchMode=yes -o IdentityAgent=none \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" \
  "midclt call app.query | jq -r '.[] | [.name,.state,(.metadata.title // \"\"),(.active_workloads.images // [] | join(\",\"))] | @tsv'"
```

Also collect the running/custom/catalog counts and targeted byte sizes for the user corpora that drive hosted cost (`du -sb` for media, photos, camera archives, and backups; ZFS usage separately). Distinguish live data from snapshot/replication overhead. State that inspection was read-only and whether anything changed.

If an exclusion is an obvious autocorrection such as “ARR tweet” → “ARR suite,” proceed without a clarification round, state the interpretation, and list the exact excluded apps. Account for every remaining app, but group supporting infrastructure with the parent workload that makes it necessary.

For multi-terabyte portfolios, compare storage-only annual cost as well as application subscriptions. Encrypted object/cloud storage can preserve confidentiality while still failing to replace indexing, transcoding, remote streaming, or application state. A valid conclusion is often **simplify the NAS**: keep SMB/NFS/ZFS plus encrypted backups and only workloads with no economical privacy-equivalent.

## Required privacy classification

Do not collapse “privacy-focused,” “encrypted at rest,” and “zero knowledge” into one claim.

1. **True zero-knowledge / E2EE** — content is encrypted on the client and the provider does not possess the decryption key. Explicitly check whether filenames, tags, EXIF, locations, notebook names, and similar application metadata are also encrypted.
2. **Managed plaintext with a strong policy** — TLS, access controls, EU hosting, no ads/sale, or a promise that staff will not routinely access data. The provider still operates the runtime/storage and can technically read application data. This is **not privacy-equivalent to self-hosting**.
3. **Public-by-design** — for public profile/link pages, content E2EE is not meaningful. Evaluate account data, visitor IP/usage collection, cookies, and tracking instead.

Even true E2EE normally leaves service metadata visible: account identifier, IP/network logs, billing, storage volume, timing, and possibly object sizes. Say “provider cannot decrypt content/app metadata” rather than “exactly as private as self-hosting.”

## Research workflow

1. Define the actual workload and sensitive fields, not just the product category (e.g. n8n credentials/execution payloads; RSS subscriptions/reading state; change-detection URLs/snapshots/tokens).
2. Prefer official pricing, privacy, security/cryptography, and feature-limit pages. Use live rendered page text when pricing is JavaScript-generated.
3. Record billing cadence, currency, tax wording, free-tier limits, storage, and whether a price is merely “from” a minimum resource allocation.
4. For managed open-source hosting, inspect both the app and host. An app-level database encryption key does not create zero knowledge if the host controls both the database and deployment key.
5. State the functional compromise: LAN reachability, external-library/NAS workflows, plug-ins, P2P semantics, storage scaling, AI subprocessors, or reduced dashboard widgets.
6. Return a compact table: current app, best candidate, current price, privacy architecture, key compromise, official URLs. End with a short verdict separating genuine ZK-E2EE candidates from policy-based hosting.

## Market snapshot — verified 2026-08-06 UTC

Revalidate before reuse.

- **FUTO Notes → Notesnook:** free privacy tier; Essential $19.99/year. On-device XChaCha20-Poly1305 encryption; notes/notebooks/tags are zero-knowledge. Sources: https://notesnook.com/pricing , https://notesnook.com/privacy , https://help.notesnook.com/how-is-my-data-encrypted
- **Immich → Ente Photos:** 10 GB free; 50 GB $2.49/month; 200 GB $4.99/month. Photos and photo metadata are E2EE; AI is on-device. Not a drop-in Immich external-library/NAS server. Sources: https://ente.io/ , https://ente.io/features/ , https://ente.io/architecture/
- **Syncthing/Resilio → Filen:** 10 GiB free; 200 GiB €1.99/month. Zero-knowledge E2EE including metadata strings such as filenames and directory names. Cloud-hub model rather than direct P2P. Sources: https://filen.io/pricing , https://filen.io/ , https://docs.filen.io/docs/api/guides/cryptography/
- **Mealie / n8n / FreshRSS / changedetection.io → same app on PikaPods:** respectively from $3.30 / $3.70 / $2.70 / $3.40 per month. PikaPods says staff do not access pod data absent explicit support authorization, but pods are not client-side E2EE and the operator technically controls runtime/storage. Sources: https://www.pikapods.com/apps/ , https://www.pikapods.com/privacy/
- **n8n nuance:** credentials are encrypted in the DB, but the deployment stores/uses the instance encryption key; managed-host root control is therefore not zero knowledge. Source: https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/configuration-examples/set-a-custom-encryption-key/
- **Karakeep → Karakeep Cloud Pro:** $4/month or $40/year; free tier is only 10 bookmarks. Not E2EE; saved links/notes/uploads are processed server-side and may be sent to AI subprocessors. Sources: https://karakeep.app/pricing/ , https://karakeep.app/privacy/
- **Glance → Start.me Personal PRO:** $25/year. Pages private by default; PRO removes ads and third-party ad tracking, but no E2EE claim. Cannot replace Glance’s direct LAN/Docker/TrueNAS monitoring. Sources: https://start.me/pricing , https://start.me/privacy , https://support.start.me/en/articles/9182869-share-a-start-me-page
- **LittleLink Server → Carrd Pro Standard:** $19/year with custom domain; $9/year without custom-domain support. Public-by-design; Carrd collects account, IP, device, and usage information. Sources: https://carrd.co/docs/pro/plans , https://carrd.co/docs/general/privacy

## Tool/research pitfall

If bulk text extraction is unavailable, do not reduce evidence quality or repeat the same failing extractor. Pivot to official-site browser rendering plus targeted official-domain search snippets. For dynamic pricing pages, inspect rendered `document.body.innerText`; it often contains prices omitted from the accessibility snapshot. Treat this as a retry strategy, not a durable claim that any extraction tool is broken.
