# qbit_manage tracker retention on TrueNAS

Use this reference when adding or changing private-tracker minimum seeding rules in the TrueNAS-managed `qbitmanage` app.

## Goal

Model tracker policy as two linked layers:

1. `tracker:` maps every known announce hostname for the site to a stable site tag plus `private`.
2. `share_limits:` selects that site tag only when the torrent also has `private` and `noHL`, then applies a buffered `max_seeding_time` with `cleanup: true`.

This preserves the established behavior: torrents remain available while hard-linked into a media library, and become cleanup-eligible only after the required seed time once no hard links remain.

## Discovery

1. Inspect `midclt call app.query` and the running container mounts; do not assume the config path. On Luke's layout it is normally:
   `/mnt/Apps/Applications/qbitmanage/config.yml` → `/config/config.yml`.
2. Read only relevant sections (`tracker`, `nohardlinks`, `share_limits`, safe `settings` keys). Avoid printing qBittorrent credentials or private announce passkeys.
3. Check the tracker's current official HnR policy and the user's class. A newly admitted account normally implies the entry-level class, but state that assumption in the completion report and offer adjustment if the class differs.
4. Inspect the full announce list, not only qBittorrent's currently active tracker. A site may fail over between aliases. Extract only hostnames from `.torrent` metadata; never print full private announce URLs.

## Safe edit procedure

1. Parse the existing YAML before editing.
2. Make a timestamped adjacent backup.
3. Use guarded targeted insertion/replacement so an unexpected layout or duplicate rule aborts rather than corrupting the file.
4. Parse the complete resulting YAML and assert:
   - all announce aliases map to the same site/private tags;
   - the share-limit group has the intended duration;
   - `include_all_tags` contains `private` and `noHL`;
   - exclusions and `cleanup` match neighboring groups;
   - priorities remain deliberate.
5. Preserve credentials and unrelated formatting/comments wherever possible.

## Connectivity prerequisite

A RUNNING qbit_manage container does not prove it can reach qBittorrent. Check recent logs for a successful Web API connection and test the configured endpoint with the existing credentials without printing them. Stale Kubernetes service DNS is a common migration residue; replace it with the currently reachable TrueNAS-published qBittorrent endpoint only after a real authenticated API smoke test.

After changing config, restart through TrueNAS lifecycle management:

```bash
midclt call -j app.stop qbitmanage
midclt call -j app.start qbitmanage
```

`midclt call -job ...` is not valid syntax; use `-j` exactly.

## Verification

- `app.get_instance qbitmanage` reports `RUNNING` and one active container.
- Container restart count remains zero after startup.
- Logs show qBittorrent/Web API versions and `Qbt Connection Successful`.
- The initial scheduled run reaches `Finished Run` without YAML/config errors.
- Re-read the parsed config and print only sanitized rule assertions.
- If no torrent from the tracker is loaded, say that live tagging could not yet be observed; do not claim it was. The parsed rule plus successful qbit_manage run is the available verification.
- Report unrelated integration warnings (such as Notifiarr HTTP errors) separately and do not imply they block tracker enforcement unless logs show they abort the run.
