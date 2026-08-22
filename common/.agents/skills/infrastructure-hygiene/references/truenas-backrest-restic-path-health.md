# TrueNAS Backrest / restic path health

Use when Luke asks whether Backrest is healthy, why backups failed, which apps to add, Immich “is restic pushing?”, or after app path/storage moves.

## Service facts (Luke stack)

- TrueNAS catalog app `backrest` (image `ghcr.io/garethgeorge/backrest`), Web UI host port **30100**.
- Config: `/mnt/.ix-apps/app_mounts/backrest/config/config.json` (mode 0600; never print repo passwords).
- Oplog: `/mnt/.ix-apps/app_mounts/backrest/data/oplog.sqlite` — `operations.status` **3** ≈ success with snapshot, **4** ≈ fail, **1** ≈ pending/scheduled.
- Destinations: `rclone:pcloud:/Server Backups/TrueNAS/restic/<repo-id>` (**pCloud** via rclone; do not confuse with Proton Drive).
- Typical schedule: staggered **04:xx** local daily backups; prune **Sun 05:00**; structure-only check monthly.
- Process log: `/mnt/.ix-apps/app_mounts/backrest/data/processlogs/backrest.log`
- Runtime user: **568:568** (`apps`). Host paths must be readable by uid 568.
- Backrest image has **restic**, not **python3** — parse `config.json` on the host; pass `RESTIC_*` via `docker exec -e`.

## Failure class: empty `ix-app-mounts` bind

Backrest **`storage.additional_storage`** may mount:

| Container path | Wrong host path | Right host path |
|---|---|---|
| `/host/Apps` | — | `/mnt/Apps/Applications` |
| `/host/ix-app-mounts` | `/mnt/Apps/_backrest-view/ix-app-mounts` (**empty stub**) | `/mnt/.ix-apps/app_mounts` |
| `/host/Media` | missing / not applied | `/mnt/Media` |

Symptom:

```text
failed to backup: path /host/ix-app-mounts/... does not exist
```

Common plans on stub paths: **n8n, audiobookshelf, bookshelf, cleanuparr, hexos, flaresolverr**.

### Fix mount

1. Edit active `user_config.yaml` under `/mnt/.ix-apps/app_configs/backrest/versions/<ver>/` — paths under **`storage.additional_storage`**.
2. Set `/host/ix-app-mounts` → `/mnt/.ix-apps/app_mounts`.
3. Patch `templates/rendered/docker-compose.yaml` volume sources.
4. `app.stop` → `docker compose -f .../rendered/docker-compose.yaml -p ix-backrest up -d` → `app.start` (no `app.restart`).
5. Verify with `docker inspect` + `ls /host/ix-app-mounts/`.

### Fix plan paths (*arr)

Prefer live Applications configs (`/host/Apps/<app>/config`) over tiny/stale app_mounts trees.

## Failure class: Immich Media missing (plan exists)

Immich usually **already has** a plan. Verify mounts before creating another.

Canonical paths:

```text
/host/Apps/db-dumps/immich
/host/Apps/immich/data/upload
/host/Apps/immich/data/profile
/host/Apps/immich/data/backups
/host/Media/Photos
```

Live app data: `/mnt/Apps/Applications/immich/*` + `/mnt/Media/Photos` (not legacy `app_mounts/immich`).

Symptom:

```text
failed to backup: path /host/Media/Photos does not exist
```

### Pitfall: top-level `additional_storage` ignored

Media listed only under top-level `additional_storage:` is **not** applied; compose uses **`storage.additional_storage`**. Trust `docker inspect` mounts, not YAML alone.

### Pitfall: midclt app.update schema

Bulk `app.update` with full user_config keys often returns `Extra inputs are not permitted`. Prefer file edit + compose up. After UI re-save, re-check Media + ix-app-mounts binds.

### Prove Immich restic

```bash
eval "$(python3 <<'PY'
import json, shlex
cfg=json.load(open("/mnt/.ix-apps/app_mounts/backrest/config/config.json"))
repo=next(r for r in cfg["repos"] if r["id"]=="immich")
print("export RESTIC_REPOSITORY="+shlex.quote(repo["uri"]))
print("export RESTIC_PASSWORD="+shlex.quote(repo["password"]))
print("export RCLONE_CONFIG=/etc/rclone/rclone.conf")
PY
)"
docker exec -u 568:568 -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e RCLONE_CONFIG \
  ix-backrest-backrest-1 restic backup --tag plan:immich --host truenas \
  /host/Apps/db-dumps/immich /host/Apps/immich/data/upload \
  /host/Apps/immich/data/profile /host/Apps/immich/data/backups /host/Media/Photos
# `restic ls latest` must include /host/Media/Photos/.immich; full snaps are tens of GiB
```

Photos need uid 568 read (NFSv4 `nfs4xdr_setfacl` if POSIX setfacl unsupported). Never delete live `/mnt/Media/Photos` because restic exists.

### Stale restic locks

Multi-day `repository is already locked` on forget/prune (seen on **futo-notes**): unlock if no job running.

## Stale repos after app delete

Remove matching plans/repos from `config.json` after deleting apps (Dockge/MinIO). Bump `modno`, backup JSON, chmod 0600.

## What is worth adding

| Priority | App | Notes |
|---|---|---|
| High | `futo-notes` | user notes |
| High | `odysseus` | often missing from plans |
| High | HA tarballs | `/mnt/Apps/backups/hass` local-only unless planned |
| High | Immich | fix Media mount; don't duplicate plan |
| High | `proton-bridge` | after IMAP init healthy |
| Medium | Backrest config, `minecraft-modded` | if still wanted |
| Low/skip | cloudflared, unpackerr, littlelink, truenas-auto-update, rsshub, glance | rebuildable |

## Disaster-recovery (summary)

Restore to Backrest **writable** `/data/_restore-tests` (not read-only `/host/Apps`). FUTO Notes: stop briefly for Postgres consistency, restic, restore under `_restore-tests`, validate with disposable postgres container, delete restore dir.

## Health check

```bash
docker inspect ix-backrest-backrest-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
sqlite3 /mnt/.ix-apps/app_mounts/backrest/data/oplog.sqlite \
  "SELECT g.plan_id, datetime(MAX(o.start_time_ms)/1000,'unixepoch','localtime')
   FROM operations o JOIN operation_groups g ON g.ogid=o.ogid
   WHERE length(o.snapshot_id)>0 GROUP BY g.plan_id ORDER BY 2 DESC;"
grep -Ei 'task failed|does not exist' /mnt/.ix-apps/app_mounts/backrest/data/processlogs/backrest.log | tail -20
```

## Immich post-upgrade self-heal (host watchdog)

Immich sometimes stays down after `truenas-auto-update` (daily ~04:00 UTC). Docker `unless-stopped` does not restart a TrueNAS **app** left STOPPED/unhealthy.

| Item | Path / fact |
|---|---|
| Script | `/mnt/Apps/config/scripts/immich-watchdog.sh` |
| Cron | root `*/10 * * * *` |
| Health | `http://127.0.0.1:30041/api/server/ping` contains `pong` |
| Action | after 2 consecutive fails: `app.start` or stop+start; wait ~4m; ntfy on recover/still-down |
| Cooldown | 15 minutes |
| Disable | `touch /mnt/Apps/config/immich-watchdog.disable` |
| State dir | `/var/lib/immich-watchdog/` |

Optional: `EXCLUDE_APPS=immich` on auto-update; upgrade Immich manually (watchdog still covers failures).

## Pitfalls

- Never print restic passwords or TrueNAS auto-update `API_KEY`.
- Top-level `additional_storage` ≠ applied storage.
- No python3 in Backrest image.
- No `app.restart` — stop then start.
- Status **1** may be scheduled, not running.
