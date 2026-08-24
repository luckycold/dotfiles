# Proxmox cluster join, upgrades, and Ceph

Verified on Luke's `Proxmox` cluster while rebuilding a lost node and recovering a dead Ceph FSID. Resolve hostnames/IPs from `~/.agents/private-context.md`. Do not record root passwords or key material.

## Do not stop `pve-cluster` to "fix" quorum

Proxmox SSH `AuthorizedKeysFile` is `/etc/pve/priv/authorized_keys` (pmxcfs). Stopping `pve-cluster` makes new SSH fail with `publickey,password` even when the on-disk key is correct. Recover the extra vote by bringing the node back or joining a replacement; do not take pmxcfs down on a remaining node.

`pvecm expected 1` can return `CS_ERR_INVALID_PARAM` on this cluster. Join the third node before rebooting the last two 8→9 kernel holdouts.

## Join a replacement node

1. Confirm the new node's LAN link first. A Realtek `r8169` NIC can show a correct `vmbr0` static config and still be `NO-CARRIER` until the Ethernet cable is reseated.
2. Write workstation and cluster keys into `/etc/pve/priv/authorized_keys` on the new node (the pmxcfs file, not a broken overwrite of the symlink). An empty 1-byte file means key SSH will fail while password SSH still works.
3. From the new node: `pvecm add <existing-member-ip> --use_ssh 1`.
   - `--fingerprint` is the **API TLS** SHA-256 (`AA:BB:...` 32 hex pairs), not the SSH host key. Prefer `--use_ssh` when root SSH already works both ways.
4. After join, confirm `pvecm status` shows 3 votes and `pvesh get /nodes` lists the new name `online`.

## PVE 8 → 9

Follow https://pve.proxmox.com/wiki/Upgrade_from_8_to_9. Userspace can be `9.2.x` while the running kernel is still `6.8.12-*-pve` until reboot. Reboot only after corosync has 3 votes. The PVE 9 ISO virtual-media mount needs **HTTP Range**; Python `http.server` is not enough — use Caddy (or another Range-capable server). Do not mount the ARM64 ISO on x86 hardware.

JetKVM `authMode: noPassword` can drive the installer, but HID bursts drop characters; prefer paste with a short delay. Virtual media at `NO-CARRIER` time is USB gadget only and does not replace the Realtek NIC.

**USB Thread/Matter radio freezes `pve` at BIOS/POST.** The Home Assistant Matter-over-Thread USB adapter (HAOS VM `101` passthrough `usb0: host=10c4:ea60`, Silicon Labs CP210x) must be **unplugged before power-on**. If it is seated at reset, this host never leaves firmware. Boot the OS first, then plug the stick in so HAOS can attach it. A reboot that never pings is this dongle until proven otherwise — not a failed 8→9 kernel.

Debian Trixie `nvidia-kernel-dkms` **550.163.01** does not build on PVE kernel **7.0.14** (`__vm_flags`, `in_irq`, DRM `fb_create` format_info). Install `proxmox-headers-$(uname -r)`, then either NVIDIA 580+ (official `.run --dkms`) or the 550-on-7.0 DKMS patches (verified: `egeekial/nvidia-550xx-dkms-proxmox` plus a kernel-7.0 `drm_format_info` argument on `nv_drm_framebuffer_create` / `drm_helper_mode_fill_fb_struct`). Pascal GPUs (GTX 1060) cannot use `nvidia-open-kernel-dkms`. After a successful DKMS install, `modprobe nvidia` and restart `systemd-modules-load`, `nvidia-persistenced`, and `nvidia-uvm-init` without another reboot. Do not treat failed NVIDIA units as a Proxmox cluster failure — `pve-cluster` / `corosync` can be healthy while those three units are red.

## Ceph removed (2026-08-22)

Luke chose to eliminate Ceph on this 1 GbE cluster. OSDs, mons, mgrs, MDS, CephFS, and the `rbd` storage are gone. `ceph.target` is masked. Do **not** recreate Ceph unless Luke asks. HAOS stays on local ZFS `fast`; failover is ZFS replication (`pvesr` `101-0`/`101-1`) plus `ha-manager` restart to `pve2`/`pvel`, not RBD. `pve2` replica is a 256G OS-NVMe slice; `pvel` replica is the whole Samsung PM991. Kingston does not fit in the laptop; unused on `pve2`. Still unused: pve 860 EVO + 1.8T NVMe. Never `fuser -km` a ZFS mount on these nodes.

## Ceph: leftover OSDs vs rebuilt-node disks (historical)

- Never `pveceph purge` or wipe OSD devices on nodes that still hold live BlueStore LVs. Never steal the OS disk / `local-lvm` VG, or members of live ZFS `fast`/`apps`. An empty `pve/data` thin pool on the OS SSD is not a leftover drive — leave it unless Luke explicitly wants that node’s OS disk split. Do not reinstall `pve2` onto the aged Kingston SATA just to free the Samsung NVMe: unused `pve/data` can become a **ZFS partition slice** (verified: 256G `fast` replica) or an OSD without a reinstall. Kingston is a worse boot disk (~96k power-on hours) and is destined for `pvel` as extra local SSD, not as `pve2` OS. Verified path: restrict `local-lvm` `nodes` to hosts that still have `pve/data`, `lvremove` the empty thin pool, `lvcreate` the leftover extents (`pve/ceph-nvme`), then `ceph-volume lvm create --data pve/ceph-nvme`. `pveceph osd create` fails on that dm LV (`unable to get device info`). Persist `systemctl enable ceph-osd@N`. Never pass the whole OS NVMe to `pveceph osd create`. Never `fuser -km` a ZFS/NFS mount on these nodes — on `pve2` that matched the whole PID table and killed the host (needs a physical reset; JetKVM is on `pve`, not `pve2`). Spare 840 + MX100 on `pve2` are for local `dir` storage (ISOs/templates on that node only). Do not NFS-export that pool unless Luke asks.
- Rebuild-node leftover SATA/NVMe (non-OS) may be wiped when Luke has said that node's data is disposable. Confirm `lsblk`/`pvs`/`zpool import` first. A pool **name** like `fast` can exist on two different disk sets; wiping the rebuilt node's former ZFS members does not touch the other node's `fast` pool. After that, restrict the ZFS storage `nodes` list to the host that still has the pool.
- A leftover GPT with Solaris/ZFS `PARTLABEL=data` is not a live pool. Before wipe: no mounts/holders/LVM/MD, empty `zpool import`, `zdb -l` fails every label, no LUKS/XFS/BTRFS/ext/qcow superblock, and no `/etc/pve` refs. High-entropy leftover is residue, not an importable dataset.
- `pveceph osd create` has no `--wipe`. Zap the **whole disk** (`wipefs` + `sgdisk --zap-all`) first; do not create on a leftover ZFS partition. After create, persist `systemctl enable ceph-osd@N` — `pveceph` only enables `--runtime`.
- Two OSD hosts cannot satisfy default `size=3` with host-level crush. Use `size=2` / `min_size=1` (or an OSD-level crush rule). Set `ceph osd require-osd-release` to the running major after all OSDs are up.
- `pveceph install --version squid --repository no-subscription` needs `DEBIAN_FRONTEND=noninteractive` and `apt-get install -y`; disable enterprise lists that 401 without a subscription.

## Ceph monitors: 2-mon clusters never form quorum when one is gone

A leftover `mon_host` / monmap with two names and only one daemon leaves `ceph -s` hanging and `pveceph mon create` failing with `Could not connect to ceph cluster despite configured monitors`. Recover by stopping the survivor, `ceph-mon -i <id> --extract-monmap`, `monmaptool --rm <dead>`, `--inject-monmap`, then start the survivor.

Adding the 2nd/3rd mon:

- `pveceph mon create` locally `monmaptool --addv`s into the new mon's mkfs map. That can poison the live map and start an election before the new mon has a paxos store (`probing` / `handle_auth_request failed to assign global_id`).
- Empty `--mkfs` plus `ceph mon add` has the same 1→2 trap: majority of 2 is 2, so quorum dies until the empty mon syncs.
- Verified path: stop mons, inject the desired monmap on a **store clone** (`rsync`/`tar` of `/var/lib/ceph/mon/ceph-<src>/` into `ceph-<newid>/`, drop `store.db/LOCK`, `chown ceph:ceph`), start all copies together. Going 2→3, `ceph mon add` while two are already quorate keeps majority (2 of 3) **if the third is not started empty**. Clone the store for the third as well.
- After a node reinstall, stale `ceph-mon` cluster KV / `[mon.<old>]` sections make `pveceph` say `monitor already exists`. Broadcast local services (`PVE::Ceph::Services::broadcast_ceph_services`) and remove the stale conf section.

Do not start a leftover `[mds.<rebuilt-node>]` on a fresh install; `ceph mds fail` the ghost and start MDS on a node that still has the journal.

## Storage after a rebuilt node

`pvesm` `rbd` with `--add_storages 1` is the official way to expose a new pool. Smoke with `rbd create`/`rm` on that pool. ZFS storage that listed the rebuilt node should be narrowed if those disks became OSDs.

## ZFS replication (`pvesr`) for HAOS

Verified 2026-08-23. `pvesr` needs the **same storage ID** on source and target (`fast` here), not merely a pool that happens to exist.

1. Replica pools named `fast` on each failover node: `pve` (870 EVO whole disk), `pve2` (256G slice on OS Samsung NVMe `nvme0n1p4`), `pvel` (whole Samsung PM991 256G NVMe). Do not steal `pvel` OS Micron `local-lvm`. Kingston does not fit in the laptop; leave it unused on `pve2`.
2. `pve2` cutover from Kingston: `pvesr disable 101-0`, `zpool destroy fast` on **pve2 only** (does not touch `pve` `fast`), wipe Kingston. `lvremove pve/data` (empty), `pvresize -y --setphysicalvolumesize 219G`, `printf Yes | parted … ---pretend-input-tty resizepart 3 221GiB`, `parted mkpart fast 221GiB 100%`, `sgdisk -t 4:BF01`, `pvresize` to fill p3, then `zpool create -o ashift=12 -O compression=lz4 -O atime=off -O mountpoint=/fast fast /dev/disk/by-id/nvme-…-part4`, `lvcreate -l 100%FREE -T pve/data`. `parted -s resizepart` still prompts; script mode is not enough.
3. `pvel` pool: BIOS SATA must be **AHCI** (not Intel RST RAID) or the PM991 stays remapped. RAID→AHCI renamed Ethernet `enp59s0` → `enp60s0`. Wipe leftover Windows, then `zpool create … fast /dev/disk/by-id/nvme-eui.…` on the whole NVMe.
4. `pvesm set fast --nodes pve,pve2,pvel` so all three advertise that ID.
5. Jobs: `pvesr create-local-job 101-0 pve2 --schedule "*/15"` and `101-1 pvel --schedule "*/15"`. Config lives in `/etc/pve/replication.cfg`. Source follows the node where VM `101` currently runs.
6. First run waits for the next calendar tick (`*/15` → `:00/:15/:30/:45`) and a healthy `pvescheduler`. `pvesr schedule-now` can leave `LastSync -` / `NextSync pending` if the scheduler is wedged. After a successful job, `NextSync pending` again means restart `pvescheduler`. One guest lock: a full send to `pvel` delays the `pve2` incremental until it finishes.
7. If pending with no `zfs send`: `journalctl -u pvescheduler` for `cfs-lock 'file-replication_cfg' ... lock request timeout`, then `systemctl restart pvescheduler`. Confirm `pvesr status` shows `SYNCING` and `pvesm export` / `zfs send` / `zfs recv` on the pair.
8. First full send of HAOS `fast/vm-101-disk-0` (~85G used / 128G vol) over 1 GbE took ~15–20 min. Incrementals finish in a few seconds. `pvesr status` Duration is the **last** job, not the initial send.
9. Success: `State OK`, `FailCount 0`, target has `fast/vm-101-disk-0` and `fast/vm-101-disk-1` plus `__replicate_101-*` snapshots.

Failover is `ha-manager` **restart** (not live-migrate). PVE 9: `ha-manager add vm:101 --state started --failback 0 --max_restart 3 --max_relocate 2 --auto-rebalance 0`, then a strict node-affinity rule on `pve:100,pve2:50,pvel:40`. Creating the first HA group/rule **migrates all HA groups to rules** and deletes `groups.cfg`. Unused groups `mitochondria` and `Thread-Radios` had no resources and went away. `qm set 101 --onboot 0` so HA owns start. RPO is last-sync (15 min). Target root SSH must work (`HostKeyAlias` = node name). If a node cannot resolve `pve`, add `/etc/hosts` — do not stop `pve-cluster`. Do not fail-test by fencing `pve` unless Luke asks.

## HAOS failover (ideal on this cluster)

Home Assistant is active-passive. On this 1 GbE cluster, **do not put HAOS on Ceph** just for failover: 4k RBD is ~300× slower than local `fast`. The VM stays on local ZFS (`fast` on `pve`) with `pvesr` to `pve2` and `pvel` (jobs `101-0` / `101-1`, every 15 min) and `ha-manager` **restart** (strict node-affinity `ha-group-haos`, `failback 0`). That keeps local SSD speed and accepts last-sync RPO. A ZFS **mirror of two drives on one node** is only disk redundancy, not node failover. Ethernet coordinators stay on the LAN. Ceph can remain for other guests. Luke prefers Ethernet/network coordinators over a spare stick in the other server: the LAN radio stays up whichever node runs HAOS. A second USB radio on another host is only a fallback. HAOS VM `101` no longer has USB passthrough (`usb0` removed). If that CP210x stick is still seated in `pve`, unplug it before power-on — it still freezes POST. PBS is the restore path for **other** guests, not HAOS failover. HAOS `scsi0` stays `backup=0`. Keep `pvesr` + `ha-manager` restart for HAOS node loss.

## Dual PBS (hypervisor-local + TrueNAS Media)

Verified 2026-08-23. ZFS replication is **HAOS-only**. Other guests go to PBS and can come back later.

- Primary: CT `102` on `pve` `slow` (pve-only) at `192.168.1.163`, official PBS `4.2.5`, datastore `Main`. A dead `pve` takes this copy with it. Upgrade with `pbs-no-subscription`; leave the enterprise list disabled.
- Secondary: TrueNAS VM display name `pbsnas` (alphanumeric only; hyphens are rejected), hostname `pbs-nas`, `192.168.1.164/23`. Debian 13 generic cloud + official `proxmox-backup-server` `4.2.5`. Zvols `Media/vm/pbs-os` (40G) and `Media/vm/pbs-data` (2T). Do **not** put the datastore on Apps or on `pve2`/`pvel` `fast`.
- TrueNAS virt pitfalls: `zfs create -o mountpoint=/mnt/Media/...` lands at `/mnt/mnt/Media/...` — inherit the mountpoint instead. Cloud-init seed ISOs must live on a **child dataset** `libvirt-qemu` can read (`755` dir, `644` file). Do not bind the display/VNC to `0.0.0.0`. Recycled IPs need `ssh-keygen -R` before the first SSH.
- PVE storage: keep `pbs` → `.163` as the nightly vzdump target. Add `pbs-nas` → `.164` datastore `Main` with API token `root@pam!pve` (`DatastoreBackup` on `/datastore/Main`). Do not switch HAOS to `backup=1` unless Luke asks.
- Off-box copy: PBS **remote sync**, not `pvesr` of CT `102`. On the NAS PBS, remote `pve-pbs` plus pull job `pve-main` (`03:00`, `rate-in 40MiB` so HAOS keeps LAN headroom, `remove-vanished 0`). Source token `root@pam!pbsnas-sync` needs `DatastoreAudit` and `DatastoreReader` on `/datastore/Main`.
- DNS: AdGuard `*.lan.1al.cc` still points at Traefik `.0.2`. Add exact overrides `pbs.lan.1al.cc` → `.163` and `pbs-nas.lan.1al.cc` → `.164`. YAML SIGHUP does not reload AdGuard; restart the container.

## HAOS on Ceph vs local ZFS `fast`

HAOS VM `101` lives on local ZFS `fast` (SATA SSD, `cache=writethrough`). Moving it to the `rbd` pool enables `ha-manager` restart on another node if `pve` dies (`size=2` / `min_size=1` keeps IO on the surviving OSD host). It does **not** fail over USB radios: `usb0: host=10c4:ea60` stays on whichever machine the stick is plugged into, and that stick must stay **unplugged at `pve` POST**. On this 1 GbE public+cluster network, matched 4k QD1 random IO was ~260 write / ~420 read IOPS on RBD versus ~79k / ~91k on the local `fast` zvol — about **300× / 220× slower** (≈ **99.7% / 99.5%**). That is the disk path, not UI/automation latency. Cached HA control plane is mostly RAM; recorder, updates, and add-on rebuilds take the hit. Do not treat empty `local-lvm` or the OS disk as the failover path.

The 300× is the **1 GbE `size=2` replica path** (LAN RTT ~0.7 ms), not one OSD. Local `ceph tell osd.N bench` (1 GiB / 4 MiB): NVMe `osd.4` ~1.9 GB/s, `pve` 860 EVO ~490 MB/s, pve2 leftovers 300–370 MB/s except the Samsung 840 (`osd.1`) which **timed out** and had BlueStore slow-ops / ~90% wear. The Crucial MX100 (`osd.3`) also had slow-ops and 226 reallocs. Both were destroyed. The Kingston that was `osd.0` was briefly the `pve2` `fast` replica, then wiped for `pvel`. Replica `fast` is the 256G NVMe slice. Re-bench after OSD removal stayed ~180–260 4k write IOPS. Removing more pve2 OSDs would have dropped the Ceph failover replica, not made RBD look like local ZFS.

Network upgrade (same `size=2`, shared public+cluster NIC): **sequential** scales with link rate until the slower OSD (~1G → ~110 MB/s; 2.5G ~2.5×; 10G ~8–10×, then NVMe/Ceph CPU). **4k QD1** is RTT-bound (~0.7 ms, ~5 Ceph messages → ~260 IOPS), so 2.5G on the same switch is only a small bump; 10G that drops RTT toward ~0.2 ms is maybe **2–4×** 4k IOPS, not 10×, and still nowhere near local ZFS (~79k).
