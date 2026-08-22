# TrueNAS qbit_manage: tracker retention and orphan forensics

Use this reference when changing private-tracker seed-time policies or reviewing qbit_manage orphan candidates on a TrueNAS-hosted qBittorrent stack.

## Retention-rule workflow

1. **Inspect before editing.** Locate the live qbit_manage container mount and `config.yml`; do not assume the host path. Read the existing `tracker`, `nohardlinks`, and `share_limits` sections so additions preserve local naming, priorities, safety buffers, and exclusions.
2. **Verify the tracker rule from an authoritative source.** Record class-dependent requirements. If account class is inferred (for example, a newly joined account is usually the base class), state that assumption in the report.
3. **Cover tracker failover hosts.** Private trackers may announce through multiple domains. Tag every known announce/failover hostname with one common tracker tag plus `private`; never print announce URLs containing passkeys.
4. **Make the share-limit scope match the request.** A `categories:` field constrains the rule. For a tracker-wide rule across all clients/categories, omit `categories:` from that share-limit group. Preserve a deliberate manual `keep` override unless the user says otherwise.
5. **Hard-link checks are separately scoped.** qbit_manage's `nohardlinks` section requires explicit real qBittorrent category names; aggregate values such as `All`/`Uncategorized` are not a reliable wildcard. Enumerate every current category that should receive `noHL`. A future category must be added here even when the tracker share-limit rule itself is universal.
6. **Use the site's minimum plus the user's established safety margin.** Keep the same duration-unit and buffer convention as adjacent groups rather than inventing a new style. Re-number priorities if inserting between existing groups.
7. **Back up and validate before reload.** Create a timestamped sibling backup, parse the complete YAML, and assert the intended tracker tags, group duration, category scope, exclusions, and priorities.
8. **Verify connectivity before claiming enforcement.** Test qbit_manage's configured qBittorrent endpoint with the existing credentials without printing them. A syntactically correct retention rule is ineffective if qbit_manage cannot reach qBittorrent.
9. **Reload through TrueNAS lifecycle.** Use `midclt call -j app.stop <app>` followed by `midclt call -j app.start <app>`; `midclt call -job ...` is invalid, and this TrueNAS stack has no `app.restart` method. Wait for `Qbt Connection Successful` and `Finished Run`, then check the relevant group's matched torrent count.

## Interpreting a first run

- Tracker tagging and `noHL` tagging are distinct passes. A universal tracker rule can match zero torrents while expanding `nohardlinks` adds many `noHL` tags in other categories.
- Report concrete counts: newly added tags, total current tag count, share-limit group membership, actual deletion actions, and recycle-bin changes.
- `cleanup: true` does not prove cleanup occurred. Confirm explicit remove/delete log events and filesystem/recycle-bin state.
- Preserve high orphan-deletion thresholds. If candidate count exceeds `max_orphaned_files_to_delete`, the abort is a safety success—not a failure to bypass.

## Read-only orphan-candidate audit

Before raising an orphan threshold or deleting anything:

1. Parse the exact `Orphaned files detected: {...}` candidate set from the relevant run.
2. Authenticate to the local qBittorrent Web API in memory. Fetch `/api/v2/torrents/info`, then `/api/v2/torrents/files?hash=<hash>` for every live torrent (bounded concurrency is useful on large libraries).
3. Build the live manifest path as `normpath(save_path + file.name)`; include `content_path` as an alias for single-file torrents. Compare candidates in the container namespace first. Derive container-to-host path mapping from inspected mounts rather than hardcoding it.
4. Classify every candidate:
   - exact live-manifest match;
   - same basename and size under a different live torrent path;
   - basename-only near match;
   - no live-manifest match.
5. Stat each host file and record size, inode, and `st_nlink`. Group by category and top-level release directory, with total size and extension mix.
6. For `st_nlink > 1`, scan the actual media-library roots for the same `(st_dev, st_ino)` to prove the external library hard link. Mount aliases may display the same physical link under more than one path; trust link count and device/inode identity.
7. Produce representative samples across categories and release types, not a raw 100+ path dump. Include totals for linked vs unlinked data.

### Interpretation

- **qbit_manage orphan** means “not represented by a currently loaded qBittorrent file manifest.” It does not automatically mean “unneeded media.”
- A candidate with no live manifest but an external library hard link is genuinely orphaned from qBittorrent; unlinking the download-side entry leaves the library entry intact.
- A candidate with no live manifest and `st_nlink == 1` is stronger stale-download evidence, but still review release groups and application ownership before deletion.
- Sidecars (`.nfo`, `.jpg`, `.cue`, `.sfv`) may be generated or retained outside torrent manifests; classify them with their release group.
- Keep the audit read-only unless the user separately authorizes cleanup.

## Approved cleanup and category exemptions

- If `orphaned.empty_after_x_days` is greater than zero, an approved orphan cleanup **moves** candidates into `directory.orphaned_dir`; it does not immediately delete them. Preserve this quarantine window.
- For a one-time approved batch above the safety limit: save an exact path/size/inode manifest, back up the config, temporarily raise `max_orphaned_files_to_delete` just above the audited count, run once, verify every source moved to the expected quarantine path with matching size, then restore the normal threshold and run again. Do not leave the elevated guard in place unnecessarily.
- Confirm unrelated application mounts are outside `directory.root_dir` before the run. In particular, a broad `/data` container mount does not expand qbit_manage's scan beyond its configured root.
- qbit_manage has a positive `categories` selector but no `exclude_categories` selector for share-limit groups. To exempt categories such as Radarr/Lidarr from retention rules, give **every** share-limit group (including a non-cleaning default group) an explicit allowlist that omits the protected categories.
- Removing categories from config does not necessarily clear limits already written into qBittorrent. After the final qbit_manage run, set protected torrents' ratio, seeding-time, and inactive-seeding-time limits to unlimited and remove stale `~share_limit*` / limit-status tags; then query the live API to prove zero protected torrents retain finite limits or share-rule tags.
- Hard-link tagging and orphan detection can remain enabled for protected categories: neither stops an active torrent from seeding. The exclusion must cover finite share-limit/cleanup groups.

## Verification/report template

- Live torrents and manifest-file count
- Candidate count and total GiB
- Exact/near/no-match classification counts
- Candidates by category and release group
- `st_nlink == 1` vs externally hard-linked counts and GiB
- 5–10 representative samples
- Whether any deletion actually occurred
- Explicit statement that no files were changed during a read-only audit
