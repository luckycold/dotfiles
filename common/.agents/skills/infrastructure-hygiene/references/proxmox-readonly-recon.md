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

As of 2026-08-23, after the lost-node rebuild and dual-PBS standup:

- Access: resolve the Proxmox SSH target and Proton Pass SSH-agent socket from `~/.agents/private-context.md`. Use read-only commands unless Luke explicitly asks for administration.
- Cluster: Proxmox cluster named `Proxmox`, expected votes `3`, quorate with `pve`, `pve2`, and `pvel`. Join/upgrade/Ceph procedures: `proxmox-cluster-ceph.md`.
- `pve` and `pvel` userspace are PVE `9.2.x` and, after the post-join reboot, run kernel `7.0.14-*-pve`. `pve2` is a fresh x86 PVE `9.2` install on the Samsung NVMe OS disk. Unplug the HA Matter/Thread USB radio before powering `pve` (it freezes POST); see `proxmox-cluster-ceph.md`.
- `pvel` (Dell) storage: OS is the Micron 256G SATA. After BIOS SATA **AHCI**, the M.2 is `/dev/nvme0n1` (Samsung PM991 256G) used as whole-disk ZFS `fast` for HAOS replication. RAID→AHCI renamed Ethernet `enp59s0` → `enp60s0`; `vmbr0` stays `192.168.1.128/23`. AHCI reports `1/1 ports implemented` (the Micron); Kingston does not fit.
- Guests: `101` HAOS VM on `pve`; `102` PBS LXC on `pve` (`192.168.1.163`); `800` `brokkr-bridge` and `801` `brokkr-endpoint-token-test` on `pve` (stopped). Guest `103` (`matrix`) died with the old `pve2` OS disk. `104` OTBR is no longer on `pvel`. TrueNAS VM `pbsnas` (`pbs-nas`, `192.168.1.164`) is the second official PBS, not a PVE guest.
- Storage: `pve` has ZFS `fast` and `apps`/`slow`. Ceph was fully removed (2026-08-22). HAOS `101` stays on `fast`. `pve2` replica `fast` is a 256G slice on the OS Samsung NVMe; leftover `local-lvm` ~116G; local ZFS `iso` pool unchanged. `pvel` replica `fast` is the Samsung PM991 256G NVMe (Windows wiped). Kingston does not fit in the laptop. Shared storage is PBS `pbs` (`.163`), PBS `pbs-nas` (`.164`, Media 2T `Main`), and NFS `media-library`. No `rbd` storage. Nightly vzdump writes to `pbs` (currently `800`); NAS PBS pull-syncs `Main` at 03:00. HAOS stays off PBS (`backup=0`).
- HAOS failover is ZFS replication (`pvesr` jobs `101-0` pve2 and `101-1` pvel, every 15 min) plus `ha-manager` restart (strict rule `ha-group-haos`, `failback 0`). Do not recreate Ceph unless Luke asks.
- Earlier public UI discovery: `443` serves the Proxmox UI through Caddy; `8006` serves Proxmox directly via `pve-api-daemon/3.0`; auth realms include `pve`, `pam`, and OpenID realm `Authelia`. Resolve private certificate hostnames from `~/.agents/private-context.md`.
