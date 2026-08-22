# TrueNAS RomM PS3 imports from qBittorrent archives

Use this for a completed PS3 torrent that is a multipart scene archive and should become a RomM-visible game without disrupting seeding.

## Proven workflow

1. **Discover live paths; do not assume them.**
   - Inspect the qBittorrent and RomM container mounts with `docker inspect`.
   - On Luke's layout during the validated run, qBittorrent saw `/mnt/Media` as `/data`, while RomM mounted `/mnt/Media/library/games/emulation` at `/romm/library`; therefore the live PS3 directory was `/mnt/Media/library/games/emulation/roms/ps3`.
   - Treat these paths as examples and re-discover them each run.

2. **Identify and validate the source before writing.**
   - Enumerate the torrent directory and locate the first volume (`.rar` plus `.r00`, `.r01`, etc.).
   - Run `7z t <first-volume.rar>` across the full set. Proceed only on `Everything is Ok`.
   - Use `7z l -slt` and the NFO to distinguish an ISO payload from a JB/folder payload. A top-level title ID containing `PS3_DISC.SFB`, `PS3_GAME/`, and optionally `PS3_UPDATE/` is a JB/folder game, not an ISO.
   - Keep the original torrent files in place so qBittorrent can continue seeding.

3. **Extract to disposable staging under the media pool.**
   - Use a unique staging directory on the same pool, e.g. `/mnt/Media/downloads/.hermes-stage-<title-id>-$$`.
   - Extract with `7z x -y -o<stage> <first-volume.rar>`.
   - Require `<title-id>/PS3_DISC.SFB` and `<title-id>/PS3_GAME/PARAM.SFO` before conversion.
   - Use a trap/finalizer to remove only the unique staging directory after success or failure.

4. **Create a PS3-aware ISO, not a generic ISO9660/UDF image.**
   - Use Bucanero's maintained builds of Estwald/Hermes `makeps3iso`: `https://github.com/bucanero/ps3iso-utils`.
   - A disposable Docker build is suitable on TrueNAS and avoids installing compilers on the host. Build from the upstream Dockerfile, run it with `/mnt/Media:/data`, then remove the temporary image and clone after verification.
   - Invocation shape:
     `makeps3iso <extracted-title-id-directory> <destination-iso-path>`
   - **Filename pitfall:** `makeps3iso` appends `.iso` when the destination argument does not itself end in `.iso`. A target such as `game.iso.partial` becomes `game.iso.partial.iso`. For atomic publication, write to a complete temporary filename that already ends in `.iso` (for example `.romm-tmp-game.iso`), validate it, then rename it to the final filename.

5. **Name and validate the result.**
   - Prefer a metadata-friendly filename such as `Game Title (Region) (TITLEID).iso`; preserving the title ID materially helps matching.
   - Before publication, run `7z l <temporary.iso>` and require all of:
     - `PS3_DISC.SFB`
     - `PS3_GAME/PARAM.SFO`
     - `PS3_GAME/USRDIR/EBOOT.BIN`
   - Atomically rename into RomM's `roms/ps3` directory, set group-readable permissions consistent with the existing library, record exact byte size, and compute SHA-256 if a durable integrity value is useful.
   - Confirm there are no partial outputs or staging remnants.

6. **Make RomM ingest it and verify identification.**
   - Inspect `ENABLE_RESCAN_ON_FILESYSTEM_CHANGE` and `ENABLE_SCHEDULED_RESCAN`; do not assume a filesystem watcher will run.
   - Preferred user-facing path is RomM's authenticated quick scan for only the PS3 platform.
   - When operating locally as the NAS administrator and no browser session is available, RomM 5.x can enqueue the same internal RQ job from inside its container:
     - resolve the PS3 platform with `db_platform_handler.get_platform_by_fs_slug("ps3")`;
     - enqueue `endpoints.sockets.scan.scan_platforms` on `high_prio_queue` with that platform ID, `ScanType.QUICK`, and only metadata handlers whose `is_enabled()` is true;
     - poll the RQ job to `FINISHED` and fail on `FAILED`, `STOPPED`, or `CANCELED`.
   - Verify in RomM's database layer with `db_rom_handler.get_roms_by_fs_name(platform_id, [filename])`. Require a row, exact filesystem name and byte size, `is_identified=True`, expected human title, and populated metadata/artwork identifiers where available. Do not equate a successful file copy with successful RomM ingestion.

## Safety and hygiene

- Never move, rename, or delete qBittorrent's source files while the torrent is active; generate the library artifact separately.
- Abort rather than overwrite an existing final ISO.
- Check free space for the archive, extracted folder, and ISO simultaneously.
- Use PS3-specific tooling for folder-to-ISO conversion; generic disc-image tools can produce an image that looks mountable but is not correct for PS3 tooling/emulators.
- Keep scans platform-scoped to avoid unnecessary whole-library metadata churn.
- Remove disposable staging, build clones, conversion images, and accidental partial files after successful verification.
