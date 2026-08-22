# Proxmox Read-Only Recon Pattern

Use this when Luke asks the agent to "learn" or "get a feel for" a Proxmox/infra host for future support. The goal is durable orientation without making changes.

## Scope

Stay read-only unless the user explicitly asks for administration. Useful checks:

- DNS and reachability for the host/FQDN.
- Common Proxmox ports: `22`, `80`, `443`, `8006`, and Proxmox-adjacent ports such as `3128`.
- Public/unauthenticated Proxmox API endpoints:
  - `/api2/json/access/domains` can reveal auth realms without credentials.
  - inventory endpoints like `/api2/json/nodes` and `/api2/json/cluster/resources` normally return `401` without auth.
- TLS certificate subject/SAN/issuer/expiry.
- HTML asset versions from the login page, e.g. `pvemanagerlib.js?ver=...`, to estimate PVE version.
- Reverse-proxy configuration on adjacent systems if already accessible, e.g. Traefik/Caddy routing from NAS to `https://<pve-ip>:8006`.
- Home Assistant/network device trackers for hostnames, IPs, MAC OUIs, and nearby related hosts such as PBS, JetKVM, secondary PVE nodes.

## Boundaries

- Do not brute-force credentials or assume SSH/API access.
- If SSH/API auth fails, record that admin inventory requires a scoped API token or installed SSH key.
- Do not persist raw tokens, session cookies, private keys, or passwords.
- Prefer a scoped Proxmox API token for future automation; SSH with a clean sudo/admin policy is the alternative.

## Luke's Current PVE Snapshot

As of 2026-05-23, read-only SSH discovery found:

- Access: resolve the Proxmox SSH target and Proton Pass SSH-agent socket from `~/.agents/private-context.md`. Use read-only commands unless Luke explicitly asks for administration.
- Cluster: Proxmox cluster named `Proxmox`, expected votes `3`, currently quorate with `2` online nodes: `pve` (`192.168.1.2`) and `pvel` (`192.168.1.128`). `pve2` resolves to `192.168.1.254` but is offline/unreachable.
- `pve`: ASUSTeK ROG STRIX Z370-H desktop, Intel i5-8600K 6 cores, 31 GiB RAM, PVE `8.4.17`, kernel `6.8.12-19-pve`, static bridge `vmbr0` at `192.168.1.2/23` via `enp0s31f6`, gateway `192.168.0.1`.
- `pvel`: Dell G3 3579 laptop, Intel i5-8300H 4c/8t, 15 GiB RAM, PVE `8.4.19`, kernel `6.8.12-19-pve`, static bridge `vmbr0` at `192.168.1.128/23` via `enp59s0`, Wi-Fi `wlo1` down.
- Guests: `101` HAOS VM on `pve` (`192.168.1.98`, 6 cores/14 GiB, SkyConnect USB); `102` PBS LXC on `pve` (`192.168.1.163`, datastore `Main`); `800` `brokkr-bridge` VM on `pve` (4 cores/12 GiB, two virtio NICs tagged VLAN 3); `104` OpenThread Border Router LXC on `pvel` (`192.168.1.9`); `100` `hermesagent` LXC on `pve` is stopped; `103` on `pve2` is unknown/offline.
- Storage: `pve` has ZFS `fast` (Samsung 870 EVO 1TB) and ZFS `apps`/storage alias `slow` (mirror of Hitachi 1TB + Seagate 4TB, effectively ~1TB), plus NVMe LVM/local-lvm on WD SN770. `pvel` uses local/local-lvm on a 256GB Micron SSD. Shared storage includes PBS storage `pbs` (`192.168.1.163`) and NFS `media-library` snippets from TrueNAS `192.168.1.157:/mnt/Media/library`.
- Earlier public UI discovery: `443` serves the Proxmox UI through Caddy; `8006` serves Proxmox directly via `pve-api-daemon/3.0`; auth realms include `pve`, `pam`, and OpenID realm `Authelia`. Resolve private certificate hostnames from `~/.agents/private-context.md`.
- Cleanup on 2026-05-23: stale Ceph runtime units on `pve` were disabled/stopped because Ceph is no longer in use; stale `Backup_1` ZFS labels were cleared from the old Hitachi reserved partition (`...HDS721010CLA332...-part9`), which fixed `zfs-import-scan`; in-container ZFS services in PBS LXC `102` were disabled because the unprivileged container has no `/dev/zfs` and its datastore is backed by host storage. Current failed units: none on `pve`, none on `pvel`, none in PBS LXC. Remaining observations: PBS package/running version mismatch (`4.2.0-1` package, running `4.1.4`) and `pve` memory pressure from large HAOS/Brokkr allocations.
