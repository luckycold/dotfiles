# TrueNAS ninerouter / 9Router maintenance

Session-derived maintenance pattern for Luke's TrueNAS SCALE `ninerouter` custom app.

## Current deployment shape

- TrueNAS app name: `ninerouter`.
- Service/container name: `ninerouter`.
- App type: TrueNAS custom app, kept UI-manageable through middleware `app.update`.
- Preferred image: official Docker image `decolua/9router:latest`.
- Data path: `/mnt/Apps/Applications/9router/data` mounted to `/app/data`.
- Host port: `20128`.
- External URL: resolve the private route host from `~/.agents/private-context.md`.
- The app's version endpoint is `/api/version`, returning `currentVersion`, `latestVersion`, and `hasUpdate`.

## Update pattern

Use this when Luke asks to update 9Router / ninerouter on TrueNAS:

1. Inspect the app and container first:
   - `midclt call app.query | jq -r '.[] | select(.name=="ninerouter")'`
   - `docker ps --filter name=^/ninerouter$ --format '{{.Names}}\t{{.Image}}\t{{.Status}}'`
   - `curl -sS http://127.0.0.1:20128/api/version`
2. Back up the TrueNAS custom app config before changing it:
   - `/mnt/.ix-apps/app_configs/ninerouter/versions/1.0.0/user_config.yaml`
3. Keep secrets and public URL env vars exactly as-is. Do not print raw `JWT_SECRET`, `INITIAL_PASSWORD`, `API_KEY_SECRET`, `MACHINE_ID_SALT`, or API keys.
4. Prefer the official image and simple persistent data mount:
   - `image: decolua/9router:latest`
   - remove old source-runtime-only fields such as `command: [bun, server.js]` and `working_dir: /app` if migrating from a copied runtime deployment.
   - use only `/mnt/Apps/Applications/9router/data:/app/data` unless a future deployment explicitly needs extra mounts.
5. Pull the image, then update through middleware:
   - `docker pull decolua/9router:latest`
   - `midclt call -j app.update ninerouter '{"custom_compose_config_string":"<compose-yaml>"}'`
6. Verify:
   - app state is `RUNNING`.
   - container image is `decolua/9router:latest`.
   - `curl -sS http://127.0.0.1:20128/api/version` shows `hasUpdate:false`.
   - `curl -I "https://$PRIVATE_ROUTE_HOST/"` returns a Cloudflare/Traefik response.

## Karakeep catalog upgrade / Meilisearch database incompatibility

A TrueNAS Karakeep catalog upgrade can update the Meilisearch image farther than the persisted index database. The failure signature is:

- `app.query` shows Karakeep stuck in `DEPLOYING`.
- Main Karakeep container remains `Created` because Compose waits for Meilisearch health.
- Meilisearch restart-loops with: `Your database version (<old>) is incompatible with your current engine version (<new>)` and suggests `--upgrade-db` / `MEILI_UPGRADE_DB`.
- This is not a Traefik, Authelia, DNS, or Karakeep HTTP problem.

Recovery pattern:

1. Record the exact old and new versions from `/mnt/Apps/Applications/karakeep/meili_data/data.ms/VERSION` and the running image.
2. Stop Karakeep through `midclt call -j app.stop karakeep` and verify no `ix-karakeep-*` containers remain running.
3. Preserve the entire `meili_data` host path with `cp -a --reflink=auto` to a timestamped sibling directory. Verify the backup's `data.ms/VERSION` before changing anything.
4. Retrieve the existing `MEILI_MASTER_KEY` only in-process from the old container config; never print it or include it in reports.
5. Run the target Meilisearch image once against the same bind mount, same uid/gid, and same master key with `MEILI_UPGRADE_DB=true`. Preserve any catalog-supplied migration feature flags such as `MEILI_EXPERIMENTAL_DUMPLESS_UPGRADE=true`.
6. Require its `/health` endpoint to return `{"status":"available"}` and require `data.ms/VERSION` to equal the target engine version. Stop/remove the temporary upgrader, then start through `midclt call -j app.start karakeep`.
7. Verify all three long-running containers are healthy with zero restarts, Karakeep direct HTTP returns its sign-in page/assets, Meilisearch health passes, the TrueNAS app is `RUNNING`, and the protected external route redirects to Authelia rather than returning a proxy/backend error. Recheck after at least one health interval.

Observed 2026-08-13: TrueNAS Karakeep `1.2.31` upgraded Meilisearch from persisted `1.50.0` to image `1.53.0` without automatically applying the database upgrade. A one-time `MEILI_UPGRADE_DB=true` run migrated the index successfully; no catalog YAML edits were needed.

## Karakeep free-model combo diagnosis

Karakeep uses this router through an OpenAI-compatible setup (`OPENAI_BASE_URL=https://<private-route-host>/v1`) with combo model names such as `free` and `free-image`.

When Karakeep says inference failed or the 9Router dashboard appears idle:

1. Confirm both apps and the exact Karakeep AI env **without printing the key**. Check `OPENAI_BASE_URL`, `INFERENCE_TEXT_MODEL`, and `INFERENCE_IMAGE_MODEL` from `docker inspect ix-karakeep-karakeep-1` with key/token/secret values redacted.
2. Correlate both logs. Karakeep wraps many upstream failures as misleading `401 [400]` / `401 [429]`; the 9Router log contains the real model/provider error and proves whether requests arrived.
3. Inspect combos from `/mnt/Apps/Applications/9router/data/db/data.sqlite` (`combos` table), and query the live OpenCode model list at `https://opencode.ai/zen/v1/models`. Free model IDs are volatile; do not trust old combo names merely because 9Router still accepts them syntactically.
4. Test candidate models through Karakeep's own base URL/API key from inside its container. Mimic Karakeep by sending `Accept: application/json`, `response_format.type=json_schema`, and a tagging prompt whose response must parse as `{"tags":[...]}`. Without `Accept: application/json`, 9Router may return `text/event-stream`, making a raw fetch smoke misleading.
5. Test image inference separately with the standard OpenAI `image_url` data-URL shape and require parseable tag JSON.
6. Before combo changes, make a consistent SQLite backup with `sqlite3 data.sqlite ".backup <backup-path>"`. Update combos through authenticated 9Router `PUT /api/combos/<id>` so combo caches are invalidated; do not edit the live DB directly.

Observed on 9Router 0.5.50 (2026-08-10): `oc/minimax-m2.5-free` and `oc/nemotron-3-super-free` had been removed/renamed upstream, while `mmf/mimo-auto` returned 400/429. Live-tested structured-output replacements were `oc/laguna-s-2.1-free`, `oc/longcat-2.0-free`, and `oc/mimo-v2.5-free`; MiMo also passed image tagging. Treat these as a dated working set and re-query/re-test when they fail.

## Pitfalls

- Do not update this as a standalone Docker Compose project; keep it as the TrueNAS-managed app.
- Do not blindly copy all old runtime mounts forward. A previous setup used `/mnt/Apps/Applications/9router/data/runtime:/app` with `oven/bun`; the official Docker image already contains the runtime, so that mount can pin the app to an old version.
- Do not expose or repeat the app's secrets when inspecting `app.config` or `user_config.yaml`.
- A model returning HTTP 200 is not enough for Karakeep. Some free models return an upstream error inside a nominal 200 response, reject `json_schema`, or wrap JSON in Markdown. Require `message.content` to parse as the schema Karakeep expects.
