# TrueNAS helper-app retirement and hosted alternatives

Research snapshot: **August 2026**. Re-check official pricing and privacy terms before acting; prices and quotas below are dated evidence, not permanent defaults.

## Decision method

For each helper app, ask in this order:

1. **Does its workload still exist?** Do not replace helpers for retired origins, databases, feeds, or notification producers.
2. **Must some code remain beside the NAS/LAN data?** Tunnels, reverse proxies, backup readers, DB dumpers, and Proton Bridge require a trusted local endpoint; SaaS cannot remove that requirement.
3. **Can a desktop client replace a server UI?** Prefer local pgAdmin/DBeaver, direct provider clients, or local rclone over a hosted console holding credentials.
4. **What privacy property is actually offered?**
   - **E2EE / zero-knowledge:** provider cannot decrypt content.
   - **ZDR:** provider processes plaintext but promises not to retain it; not E2EE.
   - **TLS / hosted privacy:** provider can read the data; TLS only protects transport.
5. **Minimize control-plane count.** Tailscale may replace public proxy + edge SSO for private-only services; Cloudflare Tunnel + Access may consolidate public routing and authentication, but still needs a local connector.

## Retirement matrix

### Usually disappears with the app estate

- `truenas-auto-update`: no apps means no updater. If apps remain, prefer reviewed TrueNAS **Bulk Actions → Update All** during maintenance.
- Traefik, cloudflared, Authelia, LLDAP: remove when no local origins remain. If origins remain, a local connector/proxy or private-network endpoint remains necessary.
- pgAdmin and `db-backup`: remove after dependent databases retire and a final encrypted dump has been restore-tested.

### Disappears if its consumers disappear

- 9Router/ninerouter, Apprise, ntfy, RSS-Bridge, RSSHub, YouTube Operational API, Proton Bridge, AList.

### Does not automatically disappear

- HexOS: manages the NAS itself, not just apps.
- Backrest/restic: remaining NAS datasets still need off-site backups.
- AdGuard Home: LAN DNS filtering is independent of NAS apps.

## Economical alternatives and privacy classification

### NAS management and updates

- Native TrueNAS UI: local, $0, best privacy.
- TrueNAS Connect: Foundation free (2 systems); Plus $60/year or $6/month (3 systems, history/replication/inventory). Hosted operational telemetry; no zero-knowledge claim.
- HexOS snapshot: $199 early-access lifetime per server; regular price stated as $299. Prefer native TrueNAS if the convenience layer is not needed.

Official: <https://connect.truenas.com/pricing/> · <https://hexos.com/> · <https://apps.truenas.com/managing-apps/managing-installed-apps/>

### Private access, public edge, and identity

- Tailscale: free up to 6 users; Standard $8/user/month. WireGuard device traffic is genuine E2EE and Tailscale says it cannot decrypt it. Best for private-only apps; clients must join the tailnet.
- Cloudflare Zero Trust: free up to 50 users; pay-as-you-go $7/user/month. Can replace Authelia/LLDAP for edge access and sometimes direct-route origins without Traefik, but `cloudflared` must still run near retained origins. Cloudflare normally terminates public TLS and sees identity/access metadata: hosted privacy, not browser-to-origin E2EE.
- Native LDAP consumers have no equally small zero-knowledge SaaS replacement. JumpCloud may fit and advertises the first 10 users free, but is a hosted directory and is usually excessive for a homelab.

Official: <https://tailscale.com/pricing> · <https://tailscale.com/docs/concepts/can-tailscale-decrypt-traffic> · <https://www.cloudflare.com/plans/zero-trust-services/> · <https://developers.cloudflare.com/tunnel/> · <https://jumpcloud.com/pricing>

### Apprise and ntfy

- Pushover: $4.99 one-time per client platform. It supports optional true E2EE using a sender/device-held 256-bit key; explicitly configure it. Ordinary push transport encryption alone is not E2EE.
- Simplepush: 10 messages/month free or $12.49/year; supports E2EE.
- Hosted ntfy snapshot: free 250 messages/day; Supporter $5/month annually; Pro $10/month annually. TLS but no general sender-to-recipient E2EE; server can process/cache bodies.
- If no notification producers remain, delete Apprise and ntfy rather than replacing them.

Official: <https://pushover.net/pricing> · <https://pushover.net/api> · <https://appriseit.com/services/pushover/> · <https://simplepush.io/features> · <https://ntfy.sh/> · <https://docs.ntfy.sh/privacy/>

### 9Router / AI routing

- Prefer direct provider APIs when a shared gateway is unnecessary.
- OpenRouter snapshot: 25+ free models and 50 requests/day; pay-as-you-go model cost plus 5.5% platform fee; BYOK up to $25,000/month list-price inference without fee, then 5%.
- OpenRouter says prompt/response retention is off by default but request metadata is retained. Enforced ZDR restricts inference to non-retaining endpoints. This is **ZDR, not E2EE**: routers/providers must process prompt plaintext, and tools/plugins have separate policies.
- OpenRouter is not a perfect replacement for a gateway whose main purpose is multiplexing subscription/OAuth sessions; direct client logins are safer than moving those sessions to another hosted proxy.

Official: <https://openrouter.ai/pricing> · <https://openrouter.ai/docs/guides/privacy/data-collection> · <https://openrouter.ai/docs/guides/features/zdr> · <https://github.com/decolua/9router>

### RSS and YouTube helpers

- First replace generated feeds with native publisher feeds. For YouTube upload monitoring use `https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID` where sufficient.
- Public RSSHub and RSS-Bridge instances are free for public, non-credentialed routes only. Operators see source paths/IP/content. Never give a public instance private session cookies.
- FetchRSS snapshot: $4.95/month for 25 feeds. RSS.app Basic: $8.32/month annually. Both must see source URLs and generated content; not E2EE.
- Official YouTube Data API is the durable replacement. June 2026 default allocation: 100 `search.list`, 100 `videos.insert`, and 10,000 units/day for other endpoints.
- The former official YouTube Operational API instance states it shut down after a YouTube legal request. Public Piped/Invidious APIs are free but best-effort and operator-visible, not dependable privacy-equivalent replacements.

Official: <https://docs.rsshub.app/guide/instances> · <https://github.com/RSS-Bridge/rss-bridge> · <https://fetchrss.com/prices> · <https://rss.app/pricing> · <https://developers.google.com/youtube/v3/determine_quota_cost> · <https://yt.lemnoslife.com/> · <https://docs.invidious.io/instances/> · <https://docs.piped.video/docs/api-documentation/>

### Backrest, restic, and DB dumps

- A hosted storage target does not replace the trusted process that reads NAS files. Run Backrest/restic or a minimal scheduler on the NAS or another trusted local host.
- Backblaze B2 snapshot: $6.95/TB/month, usage-based. Hetzner BX11: €3.20/month excluding VAT for 1 TB.
- Restic encrypts/authenticates repository content before upload. If only the user retains the repository password/key, the storage provider cannot decrypt content; object sizes, timing, account, and traffic metadata remain visible.
- Provider server-side encryption is not the property that makes restic private.
- Retire plans for deleted app datasets, but retain and restore-test plans for remaining NAS data. Put final DB dumps inside the encrypted repository.

Official: <https://garethgeorge.github.io/backrest/> · <https://restic.readthedocs.io/en/latest/070_encryption.html> · <https://www.backblaze.com/cloud-storage/pricing> · <https://www.hetzner.com/storage/storage-box/>

### AdGuard Home

- NextDNS snapshot: free 300,000 queries/month; Pro $1.99/month or $19.90/year. Logs can be disabled or retention/jurisdiction selected.
- DoH/DoT protects transport only. The recursive resolver sees queried domains, so hosted DNS is not E2EE or zero-knowledge.

Official: <https://nextdns.io/pricing> · <https://nextdns.io/privacy>

### Proton Bridge

- Use Proton web/mobile/desktop apps, or run official Bridge on the trusted workstation that needs IMAP/SMTP. Mail Plus snapshot: $3.99/month annually.
- There is no sensible hosted privacy-preserving Bridge: Bridge decrypts locally and exposes plaintext through IMAP/SMTP; putting it on a VPS gives that host mailbox access and persistent credentials.
- Proton mailbox storage is zero-access encrypted. Proton-to-Proton and deliberately password-protected/PGP mail can be E2EE; ordinary external email is not E2EE by default.

Official: <https://proton.me/mail/bridge> · <https://proton.me/mail/pricing> · <https://proton.me/support/messages-encrypted-via-bridge>

### pgAdmin and AList

- Use desktop pgAdmin or DBeaver Community ($0) rather than a hosted DB GUI holding credentials/query text.
- No fully equivalent zero-knowledge hosted AList-style multi-cloud aggregator exists: it must hold OAuth credentials and usually inspect provider data. Prefer official clients or local rclone.
- Koofr is a partial hosted substitute: 10 GB free; 100 GB €2/month displayed, yearly billing. It connects Dropbox/OneDrive/Google Drive. Only **Koofr Vault** is explicitly client-side, zero-knowledge encrypted; connected clouds and ordinary Koofr storage do not inherit Vault protection.

Official: <https://www.pgadmin.org/download/> · <https://dbeaver.io/> · <https://rclone.org/> · <https://koofr.eu/pricing/> · <https://koofr.eu/help/koofr-vault/what-is-koofr-vault/>

## Reporting format for future retirement reviews

Keep the result compact and grouped. For every named app include:

- retirement fate: **delete**, **conditional**, or **retain workload**;
- cheapest sensible alternative and dated price;
- official URL;
- exact privacy class: **E2EE/zero-knowledge**, **ZDR**, or **hosted/TLS only**;
- a direct warning when no hosted substitute can remove the need for a trusted local agent.
