---
name: truenas-custom-apps
category: devops
description: Class-level procedures for registering, updating, and managing custom Docker apps on TrueNAS SCALE as first-class entries in the Apps list. Covers the ix-apps/app_configs directory structure, midclt usage, direct YAML edits, and workarounds when app.create is restricted. Focuses on local-only services, data preservation under /mnt/Apps/Applications, and enabling integrations for self-hosted projects such as PewDiePie's Odysseus. Complements broader infrastructure-hygiene patterns.
author: Luke
---

# TrueNAS Custom App Management via CLI and ix-apps Structure

## Purpose and Scope
This skill captures the reliable class of work for adding or modifying custom apps (e.g. email bridges, web services) so they appear correctly in the TrueNAS UI as "Custom App" with full lifecycle support (start/stop/update, metadata, versioning).

Use when:
- `midclt call app.create` fails with validation errors or is restricted for custom apps.
- You need a service to be managed alongside existing custom apps like ninerouter and odysseus.
- The service provides local resources (IMAP, SMTP, etc.) for other containers/apps on the NAS, or must be deliberately exposed on standard client-facing ports with end-to-end verification.
- Maintaining consistency with Luke's TrueNAS setup conventions (least-necessary interface binding by default, explicit public exposure when requested, specific data paths, cleanup of legacy Dockge stacks).

## Prerequisites
- Configured SSH access to TrueNAS. Resolve `NAS_SSH_TARGET`, `NAS_SSH_KEY`, and `NAS_KNOWN_HOSTS` from `~/.agents/private-context.md` at runtime. Keep `BatchMode=yes`, isolate the selected identity when needed, and require strict host-key verification. If the host key is missing or changed, stop and verify it through a trusted channel; never fall back to an unverified host or `/dev/null` known-hosts file.
  ```bash
  ssh -o BatchMode=yes -o IdentityAgent=none \
    -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
    -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" 'midclt call app.query'
  ```
- At least one existing custom app (ninerouter or odysseus) to inspect and mirror.
- Python on the NAS for safe YAML load/dump during edits.
- Pre-created data directory and awareness of image-specific init flows (e.g. protonmail entrypoint).
- For credentialed services: Proton Pass agent ready with `PROTON_PASS_AGENT_REASON` usage and consent handling.

## High-Level Workflow
When the user requests execution (e.g. "I'm not at my computer right now. I want you to initialize... for me" or "can't you do all of this yourself?"), maximize autonomous actions via tools (SSH + docker + Pass agent) before falling back to commands. Execute dir prep, metadata generation, container start/stop/restart, Pass item views (with reason), TOTP generation, status polls, and extraction of visible relay creds. Only surface "complete the interactive password step with this TOTP" when raw secrets or real-time prompts are unavoidable.

1. Explore and mirror structure from a known-good custom app (ninerouter/odysseus recommended).
2. Prepare persistent data dir and clean legacy compose stacks (via SSH).
3. Create the full `/mnt/.ix-apps/app_configs/<name>/versions/1.0.0/` tree with the required files (or use the managed app update path).
4. Use `midclt call app.metadata.generate` to index the app.
5. Start via `midclt call app.start <name>` (or direct docker compose for the ix- project). If `app.query` stays `STOPPED` with zero containers, run `docker compose -f .../templates/rendered/docker-compose.yaml -p ix-<name> up -d` then `app.start` again (see `references/upstream-compose-multi-service-apps.md`). For credentialed services, run one-time init prep via `docker run --rm -i ...`.
6. For Proton Mail Bridge-style services: use `proton-pass-agent run` with a reference-only env file and a PTY helper. The Bridge prompt order can include a security-key yes/no question before the numeric TOTP prompt; `/totp` may resolve to an `otpauth://` URI, so derive a fresh code in memory. Match login success with `was added successfully`, not a fixed phrase that omits the interposed account name.
7. After login, let the managed app perform its initial sync. `info 0` may remain locked during sync. Normally wait for unlock, then capture the newly generated relay credential without printing it, replace any stale Pass `bridge` value, and verify authenticated IMAP—not merely open ports or TLS. Rebuilt Bridge vaults can generate a different relay password. If the user explicitly needs the copyable app password before sync completes, the CLI lock is only a frontend guard: use the read-only copied-vault recovery in `references/proton-bridge-locked-vault-credential-recovery.md` rather than repeatedly stopping/restarting Bridge.
8. For updates to existing apps (catalog/community apps use the exact same user_config.yaml structure): backup + targeted edit of user_config.yaml in the versions dir (pay special attention to `network.dns_port.host_ips` and similar for published ports), then trigger update/stop+start. Note the frequent pitfall that port host_ip changes do not always take effect until a deeper redeploy or UI save — see the dedicated pitfalls subsection and `references/catalog-app-network-port-edits.md`.
9. When Luke wants HTTPS on his private app domain, resolve the exact domain and backend from `~/.agents/private-context.md`, then add `/mnt/Apps/Applications/traefik/dynamic/<name>.yml`. Skip `authelia` middleware for mobile/sync/API apps that authenticate with their own password or tokens; use Authelia for browser-only admin UIs (`references/traefik-exposure-for-custom-apps.md`). For Jellyfin specifically, where the browser should use Authelia OIDC but native apps must retain Jellyfin authentication, use the split-router design in `references/jellyfin-authelia-sso-native-clients.md`.

See `references/proton-bridge-pass-automation.md` for secure PTY login, Pass secret-reference/TOTP handling, relay-credential refresh, and initial-sync locking. See `references/proton-bridge-locked-vault-credential-recovery.md` for read-only recovery of an already-generated relay password when `info 0` is blocked by the initial-sync lock. See `references/proton-bridge-public-mail-client-exposure.md` for standard `993/587` mappings, certificate import, DNS-only mail records, NAT, external verification, ordinary protocol diagnosis, and initial-sync monitor/finalizer behavior.

For upstream `docker-compose.production.yml` stacks (prebuilt image + Postgres, no repo clone on NAS), see `references/upstream-compose-multi-service-apps.md`. For projects whose best upstream artifact is a Home Assistant add-on image—including `/data/options.json`, bundled-Postgres bind permissions, safely aligning a Better Auth local login with an explicitly requested Authelia/LLDAP identity, connecting a manual-IMAP app to Proton Bridge without exposing relay credentials or sending a test message, and securely wiring the app's authenticated Streamable HTTP MCP endpoint into Hermes—see `references/home-assistant-addon-images-and-better-auth-identity.md`. For private-domain Traefik routes and when to skip Authelia for native API clients, see `references/traefik-exposure-for-custom-apps.md`.

## Key Directory and File Patterns
See `references/ix-apps-custom-app-structure.md` for the exact layout, file purposes, and condensed examples of metadata.yaml, app.yaml, user_config.yaml, rendered/docker-compose.yaml, and README.md.

Core conventions observed:
- Compose project prefix is always "ix-" (ix-ninerouter, ix-proton-bridge).
- Data volume target: `/mnt/Apps/Applications/<name>/data` mapped to the container's config path.
- Ports: `127.0.0.1:` for container-only consumers (IMAP/SMTP bridge); `192.168.1.157:<port>` (or match an existing app) when Traefik or LAN hits the backend — see port table in `references/upstream-compose-multi-service-apps.md`.
- Active compose path on this stack is often `versions/1.0.0/templates/rendered/docker-compose.yaml` (keep in sync with `user_config.yaml`).
- Version is typically "1.0.0" for these manual custom apps.
- After file creation, `app.metadata.generate` + `app.query` confirms `custom_app: true`.

## Specific Service Examples

### Folo → FreshRSS reconciliation with RSSHub
- Treat Folo’s subscribed feed/category/title data as authoritative, but preserve FreshRSS-only feeds unless Luke explicitly requests a replacement rather than a union.
- Match in this order: exact feed URL, identical RSSHub route, exact site URL, YouTube identity/title (with explicit aliases for renamed channels), then narrow same-host/manual successors. Do not collapse same-titled feeds from different platforms (e.g. YouTube vs Patreon/Odysee/Rumble).
- Convert Folo’s proprietary `rsshub://<route>` URLs to the private local endpoint. Reuse an existing FreshRSS URL for the same route when possible so its access-key/code query remains valid; otherwise construct the local URL using the already-configured RSSHub access key **without printing it**.
- Preserve existing FreshRSS feed IDs for matched subscriptions by updating URL/title/site/category in a PostgreSQL transaction; this retains entries/read/favorite state. Import only genuinely new Folo subscriptions through `cli/import-for-user.php`, then normalize the imported rows to the exact Folo metadata.
- FreshRSS 1.29.1’s OPML import can preserve XML entities literally in some titles/query strings (`&amp;` / `amp;show`). Always run a post-import exact comparison against the planned URL/title/category set and correct imported rows transactionally.
- Before changes, export OPML + ZIP and take a PostgreSQL custom-format dump; repeat all three after success. Require final feed count, no duplicate URLs, no missing/unexpected URLs, and zero metadata mismatches.
- RSSHub YouTube failure signature: all `/youtube/...` routes return HTTP 503 with `this route is empty` while the RSSHub homepage is 200. A March 2026 image had the upstream YouTube `LockupView` regression. Back up the custom compose config, pull a current image, update the TrueNAS-managed custom app through `app.update` (not standalone Compose), and verify representative/all required YouTube routes return XML before importing them.
- An RSSHub access-controlled route returning `Authentication failed. Access denied.` simply lacks the route’s existing `key`/`code`; do not misdiagnose it as the YouTube parser regression. Never print the RSSHub key or service session credentials.

### FreshRSS podcast artwork and persistent extensions
- RSSHub podcast routes such as Spotify may emit per-episode artwork only as `<itunes:image href="…">`. FreshRSS/SimplePie can preserve the audio enclosure while omitting that image, so Folo looks richer even though the source feed contains the artwork.
- Diagnose one representative item end to end: raw feed XML, FreshRSS entry `attributes`, and `FreshRSS_Entry::content()`. If `itunes:image` is present upstream but `attributes.thumbnail` is absent, use a small user extension rather than modifying FreshRSS core.
- Register `simplepie_after_init` to map item GUID/link to a validated HTTP(S) iTunes image URL, then `entry_before_insert` and `entry_before_update` to set `thumbnail => ['url' => ...]` only when no thumbnail exists. FreshRSS renders this through its native `enclosure-thumbnail` markup.
- Existing entries need a one-time transactional backfill. On this PostgreSQL schema, `attributes` is text containing JSON; parse and rewrite it carefully, and cast with `(attributes::jsonb)` in verification queries. Require total/with-thumbnail counts to match and probe one image URL for HTTP 200 plus an image content type.
- FreshRSS extensions are persistent at `/mnt/Apps/Applications/freshrss/extensions` through the host bind mount. Back up both PostgreSQL and the full extensions tree before installing or updating extensions; verify PHP syntax inside the live FreshRSS image before publishing into the mounted directory.
- For `xExtension-ExtensionManager`, audit the requested GitHub revision first, install into the persistent extension path, enable it in the target user's `extensions_enabled` config, configure only intended repositories, and verify it survives a managed `app.stop`/`app.start`. Its UI downloads executable PHP. When the extension directory is writable to the web container, admin/CSRF controls are the primary guard and compromise has code-execution impact; prefer queue/read-only mode where the deployment supports a read-only extensions mount, otherwise limit sources to trusted repositories and disclose the risk.
- Verify functionally, not only by directory presence: load the extension classes through FreshRSS CLI, exercise the artwork hook on a real feed item without printing protected feed URLs, confirm generated image markup, inspect Extension Manager's discovered-extension list, and require zero missing thumbnails after backfill.
- To adopt pre-existing extensions into Extension Manager, use the live metadata plus FreshRSS's current `extensions.json` registry to identify the real upstream repository; never assign a plausible but unverified source. Add every verified GitHub repository to the manager config and add `.extmgr-source.json` beside each extension's `metadata.json` with the base GitHub URL and branch.
- Configure repository URLs with explicit `/tree/<branch>` and give the marker the same branch. A bare repository config has catalog branch `null`; pairing it with a marker that says `main` makes the UI think the extension came from another source and incorrectly offer a branch switch.
- Extension Manager only accepts GitHub repositories. Leave Codeberg-hosted and genuinely local extensions unmarked/unmanaged rather than inventing a GitHub origin. Back up the extension tree and the user's `config.php` before adoption, fetch every configured catalog to prove the expected installed extension is discoverable, and report available updates separately instead of silently applying them.

### FreshRSS PWA metadata behind Authelia
- FreshRSS 1.29.1 already links `/themes/manifest.json`, ships standalone-display metadata/icons, and emits Apple web-app tags; do not build a redundant extension merely to make it installable.
- If browsers cannot recognize it behind Traefik `authelia@file`, probe the manifest without following redirects. Authelia may be returning its login HTML instead of the FreshRSS manifest.
- Add a higher-priority Traefik router for only `Path(`/themes/manifest.json`)`, `PathPrefix(`/themes/icons/`)`, and optionally `Path(`/favicon.ico`)`, targeting the existing FreshRSS service with **no** Authelia middleware. Keep the main catch-all reader router protected. On the TrueNAS catalog app, every added label must include `containers: [fresh_rss]`.
- Verify externally: manifest HTTP 200 with `application/json`, each declared icon HTTP 200 with an image content type, while `/` and `/i/` still redirect to Authelia. A service worker is optional for installation and should not cache private feed content by default.
- Samsung Internet frames PWA splash icons in a square plate; Chrome does not. Do not overlay FreshRSS `/themes/icons` or `manifest.json` to fight Samsung splash framing. If a circular splash is required, use Chrome's installed web app instead of a FreshRSS icon-overlay extension.

### FreshRSS client-side entry interaction extensions
- For upgrade-safe entry-click changes, use a **user extension** that registers an ordered deferred script with `FreshRSS_View::appendScript(..., defer: true, async: false)`. Install under the persistent `/mnt/Apps/Applications/freshrss/extensions` bind mount and enable the exact metadata name in the target user's `extensions_enabled` map.
- FreshRSS 1.29.1 normal entries use `.flux`, `.flux_header`, the original article anchor `.item.titleAuthorSummaryDate > a.title[href]`, and the external-link control `.item.link > a`. Its core click and mouseup handlers bubble from `#stream`; a narrowly scoped document-capture listener can swap those actions without patching core. Stop both unmodified-primary `mouseup` and `click` for handled entries so core does not also expand them, but preserve modified/middle clicks and management, website-filter, label, sharing, dropdown, form controls, and links inside expanded content.
- Open external HTTP(S) targets synchronously inside the click handler with `_blank` and `noopener,noreferrer`; honor `context.auto_mark_site` through `mark_read`. Repurpose the old external-link control with core `toggleContent(flux, document.querySelector('.flux.current'), false)` so read-state, transitions, and global-panel scrolling remain native.
- Update the control's title/ARIA label and icon when its meaning changes. FreshRSS's `view-reader.svg` is the book/reader icon. Event delegation automatically handles AJAX entries; also redecorate on bubbling `freshrss:load-more`, which is emitted after normal infinite-scroll and global-view panel insertion.
- Test the exact event order in jsdom (website click, reader button, icon/ARIA, dynamic entries, controls, modifiers), lint/boot the PHP extension inside the live container, compare the deployed script hash with the tested source, then verify enabled state and repeat after managed `app.stop`/`app.start`. Back up extensions, system/user config, and PostgreSQL first.

### FreshRSS RSSHub Radar extension
- For an RSSHub analogue to the FreshRSS RSS-Bridge extension, use a **system extension** with the `Minz_HookType::CheckUrlBeforeAdd` hook **after** RSS-Bridge (for example priority `20`, with RSS-Bridge at `0`). RSS-Bridge may convert an already-valid Atom/RSS URL; safely unwrap only the configured bridge's `action=detect&url=...` URL, ask FreshRSS/SimplePie to parse the exact original with HTML autodiscovery disabled, and restore valid direct feeds. For non-feed webpages, prefer RSSHub when Radar matches and retain the incoming bridge URL as fallback when it does not.
- Fetch the instance's `/api/radar/rules` JSON and match the serialisable Radar subset. Cover named and optional parameters, inline optional parameters such as `/:category?.htm`, regex constraints, named/plain wildcards, query wildcards, and SPA fragment paths such as `/#/channel/:id`. Skip executable/function targets and provide an explicit `rsshub://namespace/route/params` escape hatch.
- FreshRSS 1.29.1 requires PHP cURL but does **not** require `allow_url_fopen`: use bounded cURL, disable redirects, accept only HTTP(S), require HTTP 2xx, and never log the credential-bearing request URL or cURL error details.
- Read administrator configuration using `Minz_Request::paramString(..., true)`; the deprecated `Minz_Request::param()` HTML-escapes values and can corrupt keys containing `&`, `<`, quotes, etc. Escape only when rendering `configure.phtml`.
- Prefer RSSHub **`code=` authentication** (`md5(request_path + ACCESS_KEY)`) for generated feed URLs. FreshRSS logs complete fetched feed URLs, so `key=` would leak the reusable master access key into application logs; a per-route code limits exposure.
- Store Radar JSON under FreshRSS's private data cache rather than shared `/tmp`; use a secret-derived hash only as the filename, mode `0600`, no symlink directory, JSON-decode/validate **before** caching, and delete/refetch malformed cache entries.
- Before install/update, back up the full persistent extensions tree, `data/config.php`, and a PostgreSQL custom-format dump. Install under `/mnt/Apps/Applications/freshrss/extensions`, preserve owner/mode, enable in system `extensions_enabled`, and leave genuinely local extensions unmanaged by Extension Manager.
- Verification: PHP-lint every extension file, run pure matcher/auth tests, probe live `/api/radar/rules`, test manual and automatic hooks without printing query values, recover deliberately malformed cache, perform a temporary real `FreshRSS_feed_Controller::addFeed()` followed by cleanup, then managed `app.stop`/`app.start` and repeat the checks as the web user.
- If an RSSHub route is currently HTTP 200/XML but FreshRSS still shows no updates and logs `For that domain, will first retry after ...`, inspect `data/Retry-After/`. A prior 429/503 creates a future-mtime `.txt` lock; for an internally resolved hostname FreshRSS hashes the **full credentialed URL**, so the file is route-specific rather than simply `<host>.txt`. After proving that exact route now returns valid XML, remove only its matching stale lock, force `FreshRSS_feed_Controller::actualizeFeedsAndCommit(<feed-id>)`, and require new entries plus `inError=false` and `getRetryAfter(...)=0`. Do not clear every retry lock indiscriminately. On PostgreSQL, avoid `listFeedsNewestItemUsec(<id>)` for this diagnosis because FreshRSS 1.29.1's query lacks `GROUP BY`; use `EntryDAO::listWhere('f', <id>, ..., sort: 'date', order: 'DESC')` instead.

### RomM multi-file folder ingestion
- For archive-backed folder-format games, discover the live RomM host-path mount first and publish the completed game directory atomically. For PS3 JB folders, the destination shape is `<Title>.ps3/{PS3_DISC.SFB,PS3_GAME,PS3_UPDATE}` with no extra serial/release directory.
- Normalize the **entire extracted tree** to the RomM runtime ownership/modes before scanning (on Luke's current deployment: `568:568`, directories `0755`, files `0644`). Archive extractors can preserve nested directories as `0700`; fixing only the title directory lets RomM see `PS3_DISC.SFB` while silently skipping `PS3_GAME` and `PS3_UPDATE`.
- Treat metadata identification as insufficient verification. From inside the RomM container, recursively compare file count and byte total with the host extraction, then after a complete platform scan require the RomM `RomFile` inventory and `fs_size_bytes` to match and explicitly require payload markers such as `PARAM.SFO` and `EBOOT.BIN`.
- Replace formats conservatively: validate and publish the new folder before removing a superseded ISO; remove only that stale missing RomM record, and retain the qBittorrent payload for seeding unless deletion was explicitly requested.
- See `references/romm-multifile-folder-ingest.md` for the safe staging sequence, deterministic permission repair, container-side red/green probe, partial-scan failure signature, and verification checklist.

### qbit_manage private-tracker retention
- For tracker-specific HnR/minimum-seed changes, inspect the live config mount first, map every announce/failover hostname to one stable tracker tag plus `private`, and select it through a buffered `share_limits` group that also requires `noHL`.
- A RUNNING container is insufficient verification: prove the configured qBittorrent Web API endpoint works, restart with `midclt call -j app.stop/start`, and wait for `Qbt Connection Successful` plus `Finished Run`.
- Never print private announce URLs/passkeys or qBittorrent credentials. If no matching torrent is loaded, report that live tagging remains unobserved rather than claiming it passed.
- See `references/qbit-manage-tracker-retention.md` for the guarded edit procedure, migration-connectivity pitfall, and verification checklist. Keep tracker identities and account-specific policies out of the skill.

### Glance (community catalog + host paths, not ixVolume)
- Prefer **official catalog** (`train: community`, `catalog_app: glance`) when Luke wants upstream Glance with TrueNAS lifecycle — not a hand-registered custom app.
- Storage: set `storage.config.type` to `host_path` → `/mnt/Apps/Applications/glance/config` (maps to `/app/config`). Add `additional_storage` host_path → `/mnt/Apps/Applications/glance/assets` at `/app/assets` to match [docker-compose-template](https://github.com/glanceapp/docker-compose-template) (`config/glance.yml`, `config/home.yml`, `assets/user.css`).
- Seed those files from upstream **before** `midclt call app.create` (job returns immediately; poll `core.get_jobs` until SUCCESS). `run_as` **568:568**; `chown -R 568:568` on the host tree first.
- CLI install shape: `app.create` with `custom_app: false`, `version: "1.0.3"`, and `values` matching `questions.yaml` (see catalog `trains/community/glance/1.0.3/questions.yaml`).
- Default web port in catalog: **30426** (published). Verify: `curl http://192.168.1.157:30426/` → 200; `app.query` volumes should show both host paths, `custom_app: false`.
- Original: oven/bun:1.3.2-alpine image + custom command.
- Updated to: decolua/9router:latest (official), removed command/working_dir, simplified volumes to data mount only.
- Process: Backup user_config.yaml with timestamped .bak, python yaml edit, trigger update.
- Result: App continued as RUNNING custom_app with new version in runtime.

### proton-bridge (for Odysseus email integration)
- Image: shenxn/protonmail-bridge:latest (unofficial but maintained headless image with socat + entrypoint).
- Ports: local Bridge backends are IMAP 1143 and SMTP 1025. The image's `socat` frontends are container 143 and 25. For conventional public clients, map host `993→143` after enabling Bridge IMAP SSL, and host `587→25` while leaving Bridge SMTP on STARTTLS; see the public-exposure reference.
- Volume: data dir → `/root` for this image so Bridge config, cache, GPG/pass state, and vault persist together.
- Pass item: locate the Proton account/Bridge **login** item through the scoped Proton Pass agent; use `--filter-type login` so alias items are not mistaken for credentials. Do not record usernames, TOTP seeds, relay passwords, SMTP passwords, item IDs, or vault IDs in the skill.
- Relay credentials: retrieve only at runtime. A saved `bridge` field can be stale after vault rebuild/account re-add; capture the newly generated relay credential after sync unlocks, update Pass, then verify authenticated IMAP. Never print values or include them in logs/summaries.
- Init automation: stop the managed app, run a PTY helper through `proton-pass-agent run`, answer the security-key question before the TOTP prompt, derive a numeric TOTP from an `otpauth://` URI when needed, and match `was added successfully`. Use a temporary direct `protonmail-bridge --cli` container against the shared `/root` volume.
- Current TOTP handling: obtain the TOTP field at runtime through the scoped Proton Pass workflow. If it resolves to an `otpauth://` URI, derive a fresh numeric code in memory and send it only at Bridge's `Two factor code:` prompt—never at the preceding security-key yes/no prompt. Never embed or print a TOTP URI, seed, or code.
- Retrieve / confirm: while the managed app is stopped and no other Bridge process owns the vault, use a temporary CLI and `info 0`. During initial sync the user may be locked; normally resume the managed app and wait instead of repeatedly starting competing CLI containers. When the user explicitly needs the copyable relay password immediately, recover it read-only from copies of the encrypted vault and its GPG-backed vault key as documented in `references/proton-bridge-locked-vault-credential-recovery.md`; do not interrupt sync merely to retry the blocked CLI. For health checks, prefer `references/proton-bridge-imap-health-libfido2.md` and `scripts/probe-bridge-imap.sh` over `nc -z` alone.
- Purpose: provide IMAP/SMTP relay for clients without giving each client the Proton account password. Keep listeners local by default; when the user explicitly requests public client access, use standard TLS ports and complete every DNS/NAT/external-verification step in `references/proton-bridge-public-mail-client-exposure.md`.
- Post-registration: the app must appear in TrueNAS Apps, survive recreation, retain the certificate mount/path when configured, and pass authenticated protocol checks—not just show `RUNNING`.
- When the user requests autonomous execution, carry out all non-secret preparation and verification. By default, do not print the generated relay password; store/update it in the approved password manager and tell the user where it is stored. If the user explicitly asks to copy that generated Bridge app password into the current chat, reveal only the requested relay credential once, clearly distinguish it from the Proton account password, and never include it in logs, memory, skills, or general summaries.
- See `references/proton-bridge-pass-automation.md` for secure PTY login, secret-reference injection, TOTP URI handling, sync locks, and relay-credential refresh.
- See `references/proton-bridge-public-mail-client-exposure.md` for standard client ports, certificate import, public DNS/NAT, stale-lock cleanup, and external verification.
- See `references/proton-bridge-imap-health-libfido2.md` and `scripts/probe-bridge-imap.sh` when the app is RUNNING but IMAP/Himalaya hangs (libfido2, empty CAPABILITY, incomplete init).

### Upstream compose stacks (e.g. FUTO Notes sync server)
- No repo clone: curl upstream production compose + env example; `docker pull` on NAS.
- Register as custom app `futo-notes`: server + Postgres, data under `/mnt/Apps/Applications/futo-notes/data/`, and a private-domain Traefik route without Authelia.
- Full recipe: `references/upstream-compose-multi-service-apps.md`.
- **Blob volume permissions:** the server image runs as `bun` (uid **1000**). After creating `/mnt/Apps/Applications/futo-notes/data/blobs`, run `chown -R 1000:1000` on `blobs/` or sync uploads fail with `EACCES: permission denied, mkdir '/data/blobs/<user-id>'` while the client still shows “syncing”.

## Pitfalls and Anti-Patterns
- Never rely solely on `midclt call app.create` for custom apps on this system — it consistently hits validation blocks. Manual structure replication is the proven path.
- Legacy Dockge stacks at `/mnt/Apps/Applications/dockge/stacks/<name>` will conflict; remove them proactively.
- Start jobs are asynchronous — always poll `app.query` + `docker ps --filter name=<name>` and wait for "Up".
- **First `app.start` with no containers:** `app.query` may show `STOPPED` and `docker ps` shows no `ix-<name>-*` — run compose from `templates/rendered/docker-compose.yaml`, then `app.start` again until `RUNNING`.
- **Reusing a Home Assistant add-on image as a TrueNAS custom app:** A prebuilt add-on image can be the cleanest upstream artifact when it includes its own database and launcher. Mount `/mnt/Apps/Applications/<name>/data` to `/data`, seed the add-on's expected `/data/options.json`, and preserve that directory. Ensure the bind root is traversable by internal service users (`chmod 755 .../data` when appropriate): a root-owned `0770` bind root can let the launcher `chown /data/postgres` yet still make `initdb` fail with `Permission denied` because the container's `postgres` user cannot traverse `/data`. After correcting permissions, stop/start through `midclt`, require both app `RUNNING` and container health `healthy`, then verify database health, authenticated login, and persistence across another managed stop/start.
- Data dir must exist with correct ownership **before** first start (and again after manual edits as root). Read `run_as.user` / `run_as.group` from the catalog `questions.yaml` or app metadata (Glance and most community apps default to **568:568**, user `apps`). For **host_path** storage under `/mnt/Apps/Applications/<app>/`, run `chown -R <uid>:<gid>` on every bind-mounted path **before** `app.create` / `app.start`. Catalog installs still run the `permissions` init container — verify with `ls -la` on the host path after deploy; files should be owned by `apps`, dirs `775`/`664` or similar, not `root:root`. If the app cannot write config or serves empty pages, fix ownership on the host path and `app.stop` then `app.start`. Custom images with non-568 UIDs (e.g. FUTO `1000:1000` on `blobs/`) must match the image user, not blindly 568.
- YAML edits: Always backup first; prefer python snippets over sed for complex service blocks.
- **TrueNAS catalog-app labels require container assignment:** each item in `values.labels` must include `containers: [<catalog container name>]` (for FreshRSS, `[fresh_rss]`). Adding only `key`/`value` makes `app.update` fail render with `Label [...] must have at least one container`. A failed update can still leave those invalid labels in `app.config`; immediately submit a corrected label set through `app.update`, then verify the app is RUNNING and the rendered container labels.
- Secrets/credentials: Use the pre-configured proton-pass-agent + explicit reason for every vault/item operation. Respect system blocks on secret viewing. Never embed real passwords in commands, logs, or memory. After obtaining bridge info, consider storing the *generated* bridge creds back into a new Pass item.
- Port binding: Omitting `127.0.0.1` on intentionally local-only services exposes them on all interfaces — use `127.0.0.1` by default. When public mail-client access is explicitly requested, bind only the required standard ports, document the exposure, and verify the complete chain rather than treating an all-interface Docker publish as internet reachability.
- **Bridge public-mail protocol mapping:** `shenxn/protonmail-bridge` fronts Bridge with `socat`: container `143→1143` and `25→1025`. For standard clients use host `993→143` with Bridge IMAP switched to SSL, and host `587→25` with SMTP STARTTLS. Do not forward implicit-TLS 993 to a STARTTLS-only backend.
- **Probe Bridge using its configured encryption mode:** after IMAP SSL is enabled for public 993 service, the same Bridge backend reached through a localhost 1143/socat path may expect implicit TLS. A successful TCP connect followed by no plaintext greeting or CAPABILITY response can therefore be a protocol mismatch, not an uninitialized mailbox. Inspect the consumer configuration (`host`, `port`, `encryption.type`) and test with matching TLS/STARTTLS semantics; an authenticated Himalaya list against the configured endpoint is stronger evidence than a raw plaintext socket probe. Continue to classify the scan as incomplete only when the correctly matched authenticated probe fails.
- **Cloudflare mail DNS:** orange-cloud A/AAAA records normally do not proxy IMAPS 993 or SMTP submission 587. Use a DNS-only mail hostname pointing at the WAN address unless a mail-capable TCP proxy product is deliberately configured. Verify from an external network after router NAT/firewall rules are installed.
- **Generated relay credential staleness:** a rebuilt Bridge vault can generate a different mailbox password. A valid certificate and open ports can coexist with `no such user`; capture/update the current Bridge relay credential after sync unlocks and prove it with authenticated IMAP.
- **Do not diagnose mobile-mail failures from `socat` resets alone:** a reset can occur after successful STARTTLS and encrypted SMTP authentication activity. Prove IMAP/SMTP auth mechanisms independently, capture one exact retry, reassemble the protocol stages, and correlate all Bridge logs by timestamp. Once a fresh hostname or packet path disproves caching, drop that theory. TLS 1.3 ciphertext and a correctly sized masked password do not reveal the submitted credential; never intercept it.
- **Initial-sync monitor timeout is not a Bridge failure:** fixed-count polling loops can expire while progress is healthy. Check app/container/restart state, then continue with an indefinite or durable monitor and verify one-shot finalizers actually ran before rescheduling them.
- Inspecting middlewared (crud.py, custom_app.py, ix_apps/*) is useful for understanding why manual registration works, but not required for routine additions.
- **`midclt call app.restart <name>` does not exist** on this stack (`Method does not exist`). Restart custom apps with `app.stop` then `app.start`, then poll `app.query`.
- **proton-bridge + Bridge v3 auto-update:** missing `libfido2.so.1` breaks the Bridge launcher; `docker exec apt-get install libfido2-1` is only a hotfix until the next recreate. Persist via custom image or entrypoint hook. Even with libfido2, IMAP stays silent until Proton login completes in the data volume — see `references/proton-bridge-imap-health-libfido2.md`.
- **Empty data dir + RUNNING app (Jun 2026):** `ls /mnt/Apps/Applications/proton-bridge/data/` showing only directory entries (no vault files) means Proton login never finished. `midclt call app.stop` + `app.start` after installing libfido2 **recreates** the container and **wipes** the ephemeral apt hotfix; IMAP CAPABILITY stays empty. Cron email scans must report **incomplete**, not zero important mail. Human must complete Bridge init (account password); Pass `extra_fields.bridge` / `get-himalaya-bridge-pass` success does not prove IMAP is up.
- **Bridge CLI keychain/password-manager failure signature (Jul 2026):** Container logs may show `Failed to add test credentials to keychain`, `dbus-launch: executable file not found`, `pass not initialized`, `Could not load/create vault key`, and `Proton Mail Bridge is not able to detect a supported password manager`. If this appears with an empty `/mnt/Apps/Applications/proton-bridge/data`, the listener can still accept TCP while returning empty IMAP banners/CAPABILITY; do not let Himalaya hang indefinitely. Use a short CAPABILITY probe/`timeout himalaya ...`, report the scan as incomplete, and repair Bridge init/keychain rather than declaring no mail.
- **Bridge API TLS mismatch / DNS interception signature:** If Bridge logs show requests to `mail-api.proton.me` failing because the presented certificate belongs to an internal Traefik hostname, treat this as DNS/routing interception, not a generic Proton outage. Check name resolution from inside the Bridge container and the NAS resolver path before restarting or reinitializing. This can coexist with `app.query` reporting `RUNNING`, a successful TCP connection to port 1143, an empty IMAP banner/CAPABILITY, and an unpopulated data directory. None of those transport-level checks establishes a usable mailbox; automated scans must return **incomplete**, never “No important emails found.”
- **Distinguish historical Bridge errors from the current blocker:** Before attributing a failed scan to DNS interception, compare log timestamps with the current run, inspect a recent window (`docker logs --since 10m ...`), and re-check `mail-api.proton.me` resolution on both the NAS and inside the container. Old TLS/Traefik errors may remain after DNS has recovered. If current DNS is correct but the persistent Bridge data directory is still empty and IMAP returns no valid banner, report incomplete initialization/login as the active blocker rather than presenting stale DNS errors as current. Do not restart merely because old errors exist; restarting cannot complete the missing account login and may remove ephemeral container hotfixes.

### Catalog / Existing App Port Host-IP Changes (dns_port etc.)
Catalog apps (community train) and many existing apps use the identical `user_config.yaml` layout under versions/.

Typical block to target:
```yaml
network:
  dns_port:
    bind_mode: published
    host_ips: ["192.168.1.157"]   # the value to change
    port_number: 53
```

Process:
- Always `cp ... .bak.$(date +%s)` then python yaml edit.
- **Major pitfall**: `midclt call app.stop <name> && sleep && midclt call app.start <name>` (or container restart) frequently does **not** move the published host IP. The Docker publish sticks to the old IP until a deeper update/upgrade or UI-triggered redeploy. Always verify with `docker inspect <ix-...> --format '{{json .NetworkSettings.Ports}}'` and `ss -tuln | grep :53`.

When the user explicitly wants a particular alias to be the *client DNS server* (the one DHCP distributes and clients actually query for internal rewrites), do not wait for the app binding. Add a host-level iptables DNAT bridge right away:

```bash
iptables -t nat -A PREROUTING -d 192.168.0.2 -p udp --dport 53 -j DNAT --to-destination 192.168.1.157:53
# same for tcp + the OUTPUT chain for local-origin tests
```

Persist with a small idempotent script + `@reboot` root cron (or TrueNAS Post Init). Resolve the private test hostname from `~/.agents/private-context.md`; see `references/catalog-app-network-port-edits.md` for verification and cleanup.

Goal-clarification note (from user correction in session): Before touching DHCP or port publishes on dual-IP hosts, explicitly restate and confirm "the IP we want clients to use as their DNS resolver" vs "the IP the resolver will return as the A record for the service". Conflating the two produced the "I really don't think you're understanding me here" signal.

## Verification Checklist
- `midclt call app.query | jq '.[] | select(.name == "<name>") | {name, state, custom_app, version}'` → state=RUNNING, custom_app=true.
- `docker ps -a --filter name=<name>` shows container with correct port bindings.
- App visible in TrueNAS web UI under Apps.
- Data dir populated after init (`ls /mnt/Apps/Applications/<name>/data`).
- Local connectivity test from the intended consumer using the configured protocol mode.
- For public mail exposure: TLS hostname verification, authenticated IMAP/SMTP, DNS-only public record, WAN NAT/firewall, and probes from a genuinely external network all pass. Split DNS/hairpin success alone is insufficient.
- No old compose project conflicts.

## Related Skills and Overlaps
This skill focuses on the registration and structure mechanics for custom apps. It overlaps with the broader `infrastructure-hygiene` skill (Luke's TrueNAS/Home Assistant patterns). The background curator should consolidate if duplication grows. Also relevant for any self-hosted AI workspace setup (Odysseus) that needs supporting local services.

## How to Extend
- Add new references/ for specific images or common services.
- Capture new workarounds (e.g. new midclt behaviors after TrueNAS updates) via patch.
- When a user corrects the approach or a step fails in a repeatable way, patch this skill immediately.

Consult this skill before any new custom app work on the TrueNAS.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, never record credentials or secret values, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.