# TrueNAS Apps pool space reclaim (Luke stack)

Use when the Apps pool / “apps folder” is near full, TrueNAS UI shows low free space on Apps, or Docker/`ix-apps` grows without a matching growth in app data.

## Live facts (verify, don’t assume)

- Pool: **Apps** on `192.168.1.157` (typical ~464 G vdev).
- Hot paths:
  - App host data: `/mnt/Apps/Applications/<app>/`
  - Catalog ix-volumes: `/mnt/.ix-apps/app_mounts/<app>/`
  - Docker root: `/mnt/.ix-apps/docker` (dataset `Apps/ix-apps/docker`)
  - Local dumps/HA tars: `/mnt/Apps/backups/`
  - User home on Apps (not Media): `/mnt/Apps/home/`

Quick inventory:

```bash
ssh -o BatchMode=yes -o IdentityAgent=none \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" \
  -i "$NAS_SSH_KEY" "$NAS_SSH_TARGET" '
zpool list Apps
zfs list -o name,used,avail -r Apps | head -80
docker system df
du -xh --max-depth=1 /mnt/Apps/Applications 2>/dev/null | sort -hr | head -25
du -xh --max-depth=1 /mnt/Apps/backups 2>/dev/null | sort -hr | head -20
'
```

Use `du -x` only when you want **one** filesystem; child ZFS datasets under `Applications/*` or `app_mounts/*` are separate mounts — prefer `zfs list -r` for true used space.

## Failure class: Docker image bloat (largest common win)

Symptom: `Apps/ix-apps/docker` ~100 G+, `docker system df` shows Images **hundreds of GB reclaimable**, only tens of **active** images.

Cause: TrueNAS app upgrades leave old image tags (n8n, Immich, mealie, maintainerr, etc.).

Safe reclaim (does not touch running containers’ images):

```bash
docker builder prune -af
docker volume prune -f          # unused volumes only
docker image prune -af          # unused images only
docker system df
zpool list Apps
```

Expect: pool CAP drop of tens of points when reclaimable was ~180 G (session pattern: ~90% → ~64% after image prune).

Do **not** use `docker system prune --volumes` casually (can delete named volumes still needed). Prefer the three-step prune above.

Ongoing hygiene: after bulk app updates, prune unused images or use TrueNAS “unset unused images” if available.

## Failure class: migration / staging leftovers

Before `rm -rf`, confirm **no container mount** and live app uses a different path:

```bash
# Reject delete if any container bind matches the path
docker ps -q | xargs -r docker inspect | \
  python3 -c 'import json,sys; ...'  # or manual inspect of target app
```

Known Luke-stack reclaim candidates (verify still unused each time):

| Path | Typical size | Notes |
|---|---|---|
| `/mnt/Apps/backups/karakeep-*` (dated precluster/restore dirs) | tens of GB | One-off migration; live Karakeep uses `/mnt/Apps/Applications/karakeep/` |
| `/mnt/Apps/home/lucky/plex-stage` | tens of GB | Staging Plex tree; live Plex is `/mnt/Apps/Applications/plex/config` |
| `Apps/ix-apps/app_mounts/immich` (legacy ixVolume tree) | ~20 G | **Not** live Immich if server mounts `Applications/immich` + `/mnt/Media/Photos` |

### Legacy Immich app_mounts destroy

Only after docker inspect shows live Immich on **Applications + Media**, never on `app_mounts/immich`:

```bash
# Live Immich should look like:
# /mnt/Apps/Applications/immich/data -> /data
# /mnt/Media/Photos -> /data/library

zfs destroy -r Apps/ix-apps/app_mounts/immich
# confirm live app still healthy + /api/server/ping
```

Backrest Immich paths must remain `/host/Apps/immich/...` and `/host/Media/Photos` (Applications + Media), **not** app_mounts.

## ZFS snapshot holdback

Deleting files under snapshotted datasets (`Apps/backups` 1‑month dailies, `Apps/Applications` 2‑week) may free less immediately than `du` suggests — space moves to `usedbysnapshots` until snaps age out. Report **available** before/after honestly.

## Local vs offsite

- ZFS snaps + `/mnt/Apps/backups/hass` = **local** only.
- Offsite app/config/library protection = **Backrest → pCloud restic** (see `truenas-backrest-restic-path-health.md`).
- After reclaim, re-check that Immich/Backrest still have correct host binds (Media + real ix-app-mounts).

## Verification checklist

- [ ] `zpool list Apps` free space improved as expected for non-snapshotted deletes / Docker prune
- [ ] Target apps still RUNNING (Immich/Plex/Karakeep/Backrest as applicable)
- [ ] `docker system df` Images reclaimable not still ~90%
- [ ] No accidental delete of `/mnt/Apps/Applications/<live-app>` or `/mnt/Media/Photos`
