# RomM Multi-file Folder Ingest on TrueNAS

Use this when importing an archive-backed game into a RomM library mounted from a TrueNAS host path, especially folder-format games such as PlayStation 3 JB folders.

## Core invariant

A metadata match is **not** proof that RomM indexed the game payload. RomM can identify a folder from its name while indexing only the one readable top-level file. Verify recursive visibility and the persisted file inventory.

## PS3 folder shape

For a folder-format PS3 game, use one title directory directly beneath the PS3 platform folder:

```text
roms/ps3/<Title>.ps3/
├── PS3_DISC.SFB
├── PS3_GAME/
│   ├── PARAM.SFO
│   └── USRDIR/
│       └── EBOOT.BIN
└── PS3_UPDATE/        # optional in some dumps
```

Do not leave an extra release/serial directory between `<Title>.ps3` and `PS3_GAME`. If the archive contains a serial root such as `BLUS12345/`, publish that root's **contents** as `<Title>.ps3/`.

## Safe ingest sequence

1. Locate the real RomM host-path mount from `docker inspect`; do not infer it from the download path.
2. Validate the multipart archive before changing the library. For RAR sets, test the first `.rar` volume and require `Everything is Ok` plus the expected volume count.
3. Extract to a hidden staging directory on the **same filesystem** as the destination. Validate required files before publishing.
4. Rename the completed serial/root folder atomically to `<Title>.ps3`.
5. Normalize ownership and permissions **recursively** to match the RomM container. On Luke's TrueNAS RomM deployment the known-good convention is UID/GID `568:568`, directories `0755`, files `0644`. Do not only chmod the title directory: archive extractors can preserve nested directories as `0700`.
6. From **inside the RomM container**, recursively walk the title directory and compare file count and byte total with the host/extraction result. Require readable `PS3_DISC.SFB`, `PS3_GAME/PARAM.SFO`, and `PS3_GAME/USRDIR/EBOOT.BIN`.
7. Only after the folder passes those checks, remove a superseded ISO or previous-format copy if the user requested replacement. Keep the qBittorrent payload intact when it is still needed for seeding.
8. Run a RomM complete scan for only the affected platform.
9. Verify the persisted RomM inventory: the ROM row's `fs_size_bytes` and the sum/count of `RomFile` rows must match the recursive filesystem inventory; explicitly require `PARAM.SFO` and `EBOOT.BIN` rows. Remove only the stale missing record for the superseded copy, not every missing ROM on the platform.

## Deterministic permission repair

Run on the TrueNAS host with the title path substituted:

```python
import os
root = "/mnt/<pool>/<romm-library>/roms/ps3/<Title>.ps3"
for directory, _, files in os.walk(root):
    os.chown(directory, 568, 568)
    os.chmod(directory, 0o755)
    for name in files:
        path = os.path.join(directory, name)
        os.chown(path, 568, 568)
        os.chmod(path, 0o644)
```

Then run the same recursive `os.walk` from inside the RomM container as UID/GID 568. A host-root walk is insufficient because root can traverse directories the application user cannot.

## Failure signature and root cause

Signature:

- RomM identifies the correct game and downloads artwork.
- The Files tab shows the `<Title>.ps3` folder as one file of about 1.5 KB.
- Only `PS3_DISC.SFB` appears.
- RomM's `fs_size_bytes` is `1536` even though the host tree is many gigabytes.

Root cause to test first: the title directory itself is traversable, but nested `PS3_GAME` / `PS3_UPDATE` directories are mode `0700` or otherwise inaccessible to the RomM runtime UID. Python `os.walk` silently skips those permission-denied subtrees, so a scan can finish successfully with a partial inventory.

## Tight red/green check

Before the fix, this container-side check must reproduce the incomplete count. After recursive permission repair, it must report the same count and byte total as the host:

```python
import os
root = "/romm/library/roms/ps3/<Title>.ps3"
files = [os.path.join(dp, n) for dp, _, names in os.walk(root) for n in names]
print(len(files), sum(os.path.getsize(path) for path in files))
for rel in ("PS3_DISC.SFB", "PS3_GAME/PARAM.SFO", "PS3_GAME/USRDIR/EBOOT.BIN"):
    assert os.access(os.path.join(root, rel), os.R_OK), rel
```

## Verification checklist

- Archive integrity test passed.
- Destination is the actual RomM-mounted platform directory.
- Folder shape has no extra serial/release nesting.
- Container-side recursive file count and bytes equal the host extraction.
- Required PS3 files are readable as the RomM runtime user.
- Complete platform scan finished.
- RomM database/file inventory equals the filesystem inventory.
- Metadata remains identified, but identification is treated as secondary evidence.
- Superseded filesystem copy and only its stale RomM record are removed.
- qBittorrent source remains available for seeding unless deletion was explicitly requested.
