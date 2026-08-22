# TrueNAS ZFS dataset busy on delete (orphan app data)

## When this shows up

Orphan app data under `/mnt/Apps/Applications/<name>` that is a **ZFS dataset** (not a plain directory). `rm -rf` fails with `Device or resource busy`. `zfs destroy -r` / `midclt call pool.dataset.delete` fail with:

```text
[EBUSY] Failed to delete dataset: cannot destroy 'Apps/Applications/<name>': dataset is busy
```

even when `mounted=no` and no app/containers reference the path.

Seen with leftover MinIO data (`Apps/Applications/minio` + `.../minio/data`) after the app was long gone; Backrest/restic is the preferred backup path instead.

## Procedure

1. Confirm no app/container use:
   ```bash
   midclt call app.query | jq -r '.[] | select(.name|test("minio";"i")) | [.name,.state] | @tsv'
   docker ps -a --format '{{.Names}} {{.Image}}' | grep -i minio || true
   ls /mnt/.ix-apps/app_configs | grep -i minio || true
   ```
2. Inventory datasets + snapshots:
   ```bash
   zfs list -t all -r Apps/Applications/<name>
   mount | grep <name> || true
   ```
3. Prefer TrueNAS middleware:
   ```bash
   midclt call -j pool.dataset.delete 'Apps/Applications/<name>/data' '{"recursive":true,"force":true}'
   midclt call -j pool.dataset.delete 'Apps/Applications/<name>' '{"recursive":true,"force":true}'
   ```
4. If destroy is stuck but data is gone or disposable:
   - `zfs set canmount=off` on child then parent
   - `zfs set mountpoint=none` on both
   - **Rename out of the way** so the Apps tree is tidy:
     ```bash
     zfs rename Apps/Applications/<name> Apps/Applications/_trash_<name>
     ```
   - Schedule a later UI delete of `_trash_*` after reboot/idle when EBUSY clears (do not `zpool export` for this).
5. Do **not** `zpool export` or stop the whole pool to free one orphan dataset.

## Success criteria

- No live service/containers for the orphan app
- Path no longer appears as a real app directory under `Applications/` (or only empty trash rename remains)
- Backup alternative (e.g. `backrest` app RUNNING) still healthy
- Large USED space reclaimed (empty shells may remain at ~96K–192K until full destroy)

## Pitfalls

- Parent `Apps/Applications` mount makes naive `fuser` on child paths noisy — many unrelated app processes appear as "holders".
- Snapshots under the dataset can keep USED high until destroyed; recursive destroy should remove them when not busy.
- Catalog entries under `/mnt/.ix-apps/truenas_catalog/.../minio` are **catalog metadata**, not user data — leave them.
