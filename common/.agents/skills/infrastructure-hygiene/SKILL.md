---
name: infrastructure-hygiene
description: Class-level devops hygiene for Luke's Hermes/TrueNAS/Home Assistant stack — harness boundaries, update/stash audit, read-only recon, TrueNAS Traefik/ACME/apps; cross-links proton-pass and web-search skills.
author: Luke
category: devops
---

# Infrastructure Hygiene

Class-level devops hygiene for user-owned infrastructure (Hermes container, TrueNAS, Home Assistant add-on, LAN hosts). Prefer conventional, UI-visible, recoverable setups over one-off hacks.

## Core Principles
- Never modify core code harnesses, especially the Hermes agent harness itself.
- The user considers their infrastructure (including the Hermes container and TrueNAS) to be user-owned. The agent is expected to keep it tidy and conventional.
- Prefer clean/official update paths or fresh sessions over local patches and workarounds.
- When redundant or hacky installations are discovered, clean them up immediately.
- **Enforcement**: harness and hygiene rules override the general desire to be helpful. When the user expresses frustration about harness modifications, consult this skill before touching Hermes core files.

## Hard Rules — Hermes code harness (non-negotiable)

Do not modify the Hermes code harness or core agent files under any circumstances. The harness was designed a certain way for a reason; local modifications, even "temporary" ones, are not acceptable.

### Prohibited actions
- Editing core files such as `agent/codex_responses_adapter.py`, `agent/chat_completion_helpers.py`, provider adapters, session/reasoning handling logic, or anything under `hermes-agent/agent/`
- Adding workarounds, monkey-patches, or custom encrypted-state handling
- Modifying how sessions, providers, or toolsets are initialized

### Correct response when something is broken
- Report the issue clearly
- Offer to start a fresh session
- Suggest official update mechanisms (`hermes update`, gateway restart, new session)
- Never patch the harness to make the current session work

### Related preferences
- Prefer clean, conventional, maintainable setups over clever workarounds
- When redundant or leftover installations are discovered (duplicate Node, stray Homebrew in temp paths), clean them up proactively
- Use proper s6 services for long-running components that must survive restarts

See `references/hermes-harness-boundary.md` for the incident that established this boundary.

## Hard Rules — operational
- **Redundant Installs**: When multiple versions of a tool or duplicate installations are found, remove the leftover/hacky one.
- **Direct Action**: When the user approves a change via tool confirmation, execute it without asking for further confirmation.
- **Tool approval ≠ chat approval**: Destructive `rm`/`zfs destroy`/`app.delete` may still require the **runtime tool-confirmation prompt**. Chat “approved / try again / do it” is not enough if the tool returns `BLOCKED: user has NOT consented`. Do not loop rephrases; ask Luke to approve the next tool popup, then retry once.
- **Home cleanup phases (Luke):** Prefer phased tidy. **HA entity unavailable/unknown purge is Phase C only** unless Luke explicitly asks for it in the same turn. Prefer stock Hermes + one intentional HA dashboard/Kagi local commit; keep `minecraft-modded` data until the ATM project is finished or Luke says otherwise.
- **Live Stow profile changes:** Do not unstow an entire active persona merely to relocate one subset. Required files can disappear between commands and trigger live reload failures (for example, Hyprland reporting a missing `hypr.autostart` module). Prepare the replacement first, relink/restow the narrow paths without a gap, then validate affected runtimes. For Hyprland, run `hyprctl reload` followed by `hyprctl configerrors`.

## Pitfalls to Avoid
- Local modifications to protected harnesses
- Leaving behind temporary or `tmp/.cellar` style installations
- Explaining what you will do instead of doing it when the user has already approved

## Kagi search/MCP in Luke's Hermes container

For Kagi CLI install, `web.search_backend`, MCP registration, and verification checklists, cross-check **`hermes-agent`** docs/skills for search wiring when needed.

Container-specific hygiene only:
- Verify paths against the active layout (`/config` in the Home Assistant add-on, not legacy `/home/hermes`). Cron jobs or workdirs still pointing at `/home/hermes/.hermes/...` will warn at runtime — report for Luke to fix; do not edit cron during unattended maintenance unless explicitly asked.
- **npm prefix:** `/config/.npm-global` (`export PATH` includes `/config/.npm-global/bin` or use `npm --prefix /config/.npm-global …`).
- **kagi-cli version pin (HAOS/bookworm):** Do **not** rely on blind `npm update -g` for `kagi-cli` on this image. **0.13+** (verified through npm latest `0.16.0` on 2026-08-02) require **GLIBC_2.39** while the container ships **glibc 2.36**. **Newest runnable npm release here: `kagi-cli@0.12.0`** (binary reports `kagi 0.12.0`). Use **`/config/.hermes/scripts/kagi-cli-update-safe.sh`** (tries latest, falls back to `0.12.0`) in weekly maintenance and after accidental bumps. Re-test schemas with `references/kagi-mcp-schema-probe.py` then `hermes mcp test kagi`.
- **Schema probe after every kagi-cli bump** (decides adapter vs native):
  - Prefer **`python3` references/kagi-mcp-schema-probe.py** from this skill (or a single inline `python3 -c '...'` subprocess probe) — no shell pipe into `python3` — so unattended/cron terminal runs avoid Tirith `pipe_to_interpreter` approval blocks.
  - Call `/config/.npm-global/bin/kagi mcp --json-lines` with initialize + `tools/list`; require explicit `properties` on `kagi_search`, `kagi_quick`, `kagi_summarize`, `kagi_news`, `kagi_news_search`.
  - **If typed:** register MCP via the **wrapper + HOME** (HAOS add-on session auth lives under `/config`):
    ```yaml
    mcp_servers:
      kagi:
        command: /config/.local/bin/kagi-mcp
        env:
          HOME: /config
    ```
    (`kagi-mcp` is a thin bash wrapper that sets `HOME=/config` and `exec`s `kagi mcp`.) Run `hermes mcp test kagi` (expect **6** tools including `kagi_extract` on 0.11.x). **Do not** use the agent `patch`/`write_file` tools on `~/.hermes/config.yaml` — they are blocked; use `printf 'y\nY\n' | hermes mcp add kagi --command /config/.local/bin/kagi-mcp --env HOME=/config` to overwrite non-interactively. The legacy typed adapter `hermes-kagi-mcp.py` can remain as fallback documentation only once native schemas are typed.
  - **Session auth sync:** `kagi auth status` reads `/config/.config/kagi-cli/config.toml`. If credentials exist only in `/config/.kagi.toml`, run `kagi auth set --session-token <token>` with `HOME=/config` (never print the token in reports). Without this, `hermes mcp test` may pass while live `tools/call` fails with `KAGI_SESSION_TOKEN`.
  - **Summarize smokes:** MCP `kagi_summarize` may require **`KAGI_API_TOKEN`** (public API path). Subscriber/session summarize works via CLI: `kagi summarize --url <https-url> --subscriber --length overview` with `HOME=/config`. Report the gap if agent sessions need summarize without a public token.
  - **If still empty `{type: object}` only:** keep `hermes-kagi-mcp.py` behind the wrapper; do not patch Hermes core for Kagi.
- **Auth for smokes:** `hermes mcp test` only checks connect/list. Bounded CLI/API smokes need `KAGI_SESSION_TOKEN` or `kagi auth set --session-token` in `/config/.config/kagi-cli/` — report missing session without printing tokens.
- Keep Kagi integration outside the Hermes core repo — no provider-specific edits under `agent/` or `tools/` except **resolving accidental merge-conflict markers** in the checkout (see weekly maintenance reference).

## Hermes Container Weekly Maintenance

For Luke's dedicated Hermes container, treat `/config` as the active home in the Home Assistant/add-on layout; `/home/hermes` may be legacy or absent. Keep the run conventional and low-risk:

- Inspect first: OS/kernel, disk, Hermes version/status, gateway status, MCP list, and git status of the active checkout (`/config/.hermes/hermes-agent` unless proven otherwise).
- Do not create/modify cron jobs during **unattended** maintenance runs unless Luke explicitly asks. When Luke directs you to **fix the weekly maintenance report** (or its follow-up list), updating `weekly-tooling-maintenance` in `/config/.hermes/cron/jobs.json` (workdir, `/config` paths, kagi-cli pin text) is in scope.
- When Luke asks to execute maintenance **follow-ups** (not just re-report), run the checklist in `references/hermes-container-weekly-maintenance.md` § **2026-07-05 follow-up execution** — disk (linuxbrew `.cellar`), `hermes update` + cherry-pick of HA/Kagi local commit, MCP adapter for subscriber summarize, config noise cleanup, and document that gateway reload requires **HA add-on restart** when blocked in-process. When the user *does* explicitly request a new hygiene/monitoring cron, create it via the `hermes cron create` subcommand (see `references/hermes-cron-creation.md`).
- Do not print secrets, auth files, tokens, connection strings, or raw `.env`/credential contents.
- Prefer safe package maintenance only: apt metadata refresh, noninteractive upgrade, autoremove/autoclean/clean. If the container is already root and `sudo` is unavailable, running apt directly is the equivalent path.
- Update user-local npm globals with the existing prefix, but **pin/fallback `kagi-cli@0.12.0`** on this HAOS/bookworm image (see Kagi subsection — blind `npm update -g` can install a glibc-incompatible kagi binary).
- Run `hermes config migrate`, `hermes config check`, and `hermes doctor` after routine updates.
- For newly announced Grok/xAI OAuth models, use the supported provider catalog + config path and a real one-shot `hermes chat --provider xai-oauth -m <model>` smoke; see `references/hermes-xai-oauth-new-model-enablement.md`. Do not patch protected Hermes core/provider code just to add a new `grok-*` slug. After switching main model to Grok, set **`model.context_length` to the real window** (Grok 4.5 is **500000**, not leftover 1M from Codex/GPT-5.5).
- Be conservative with `hermes update`/image upgrades when Hermes reports a container image update path, the git checkout is dirty, or the repo is many commits behind. Report and defer unless there is a safe rollback path and local-change audit.
- Restart the gateway only when needed for config/tool changes and only through an approved/safe mechanism; if an approval guard blocks restart in unattended cron, report that a controlled restart is needed rather than bypassing it. After switching Kagi MCP registration, `hermes mcp test` may pass immediately while the long-lived gateway still serves the old stdio command until restart or `/reload-mcp`.
- If `git status` shows **`UU` / conflict markers** in `agent/file_safety.py` (or any core path), fix before relying on file/terminal tools — unresolved markers cause `SyntaxError` and break `file_tools` / terminal cleanup (visible in `gateway.log` as `Could not import tool module tools.file_tools`). Resolve by aligning with `origin/main` for the conflict hunk, `git add`, then verify `python3 -c "from agent.file_safety import get_read_block_error"` from the repo root.
- Tidy only conventional caches/log rotations. Do not delete repos, auth files, sessions, skills, cron jobs, memories, imports, or backups without explicit instruction.

## Creating Hermes Cron Jobs (Hygiene / Monitoring / Maintenance)

See the dedicated reference `references/hermes-cron-creation.md` for the exact `hermes cron create` command shape, required flags (`--name`, `--deliver local`, `--skill` list), why `deliver=local` is preferred for low-noise jobs, the pitfall of using the generic `cronjob` tool instead, and verification with `hermes cron list`.

Key points:
- Always supply a fully self-contained prompt (fresh session).
- Explicitly attach the skills the job will need via `--skill`.
- Use `deliver=local` + conditional internal notification (NTFY, selective send_message) for jobs that should be silent unless they have a real signal (example: the morning email importance scan that only pings on important mail).
- The pattern was hardened during setup of the 8 a.m. email scan cron (himalaya + proton-pass-cli + truenas-custom-apps skills, tunnel + wrapper for bridge, conservative filter).

## Hermes Update / Stash Hygiene
When a Hermes update stashes or surfaces local harness changes, actively audit and reduce them instead of blindly reapplying everything:

- Inspect both the current working tree and all stash entries; classify each changed path by blast radius.
- Keep only narrow, concrete local integrations that use supported extension seams, such as a plugin or explicit local configuration hook.
- Drop changes that alter Hermes core harness behavior, model/provider connection semantics, global fallback ordering, or bundled dashboard source. Exception: keep Luke-approved Home Assistant add-on dashboard base-path compatibility patches; verify them against the prior autostash/add-on copy instead of treating them as disposable harness hacks.
- Prefer a plugin/config/wrapper boundary over editing `agent/`, provider registries, or dashboard internals. If a local integration needs a core hook, make it the smallest explicit-backend hook rather than a global behavior change.
- Verify with `git diff --check`, syntax checks for touched files, a focused smoke test, and a final `git status --short --branch` showing only intentional local integration files.

See `references/hermes-update-stash-audit.md` for the reusable audit checklist and the Kagi-vs-core-provider-routing example.

## Read-Only Infrastructure Reconnaissance
When Luke asks you to "learn" an infrastructure host so you can help later, do an active but read-only orientation pass instead of waiting for credentials:

- Probe DNS, reachability, common service ports, TLS certificates, and unauthenticated status/API endpoints.
- Correlate with already-accessible systems such as Home Assistant device trackers, NAS reverse-proxy configs, and prior session records.
- In the Home Assistant add-on/container, expect network vantage to differ from the LAN. Use HA/UniFi device trackers for host/IP/MAC/name, then pivot through an already-trusted LAN host such as Proxmox for ARP, DNS, nmap, and port checks when container routing or mDNS is incomplete.
- For OS identification, prefer authenticated commands (`uname`, `/etc/os-release`, `sw_vers`) when SSH works. If SSH is filtered, use read-only network fingerprinting (`nmap -O -sV -Pn`) from a same-LAN host and label it as a confidence estimate rather than exact truth.
- Identify exactly what is still inaccessible because credentials are missing, host firewall blocks access, or the service is not enabled; recommend the cleanest future access path, such as enabling SSH for the known user or installing an authorized key.
- **Verify before blaming NAS/DNS:** Luke may use `192.168.0.2` as alternate DNS on TrueNAS; confirm with `dig`, not stale "Traefik-only" assumptions.
- **Work-from-home NetBird:** unstable private routed networks on home LAN with fine hotspot behavior → check dual-homed Wi‑Fi + Ethernet on the workstation; resolve private values from `~/.agents/private-context.md` and see `references/netbird-bmc-work-pc-dual-homed.md`.
- Save durable topology facts, but not raw credentials, private keys, cookies, or transient outage/error claims.

For Proxmox hosts, see `references/proxmox-readonly-recon.md` for the reusable checklist and Luke's current PVE snapshot. For workstation/laptop discovery from the HA add-on, see `references/laptop-lan-recon.md`. For NetBird → work BMC from home, see `references/netbird-bmc-work-pc-dual-homed.md`. For idempotent UniFi WAN port-forward creation with an API key, exact legacy endpoint/schema, credential hygiene, and external verification, see `references/unifi-port-forwarding-via-api.md`.

## Proton Pass CLI for audited agent secrets

Use the **`proton-pass-cli`** skill for install, agent tokens, wrappers, `PROTON_PASS_AGENT_REASON`, headless `fs` key provider, and session repair. Resolve Luke's exact password-manager topology and local integration paths from `~/.agents/private-context.md`.

## Headless note-vault access

When Hermes needs Obsidian access from the display-less Home Assistant add-on/container, distinguish the desktop-linked official `obsidian` CLI from the standalone official `obsidian-headless` client (`ob`). Prefer `ob` for Obsidian Sync, then operate on the downloaded Markdown vault with file tools. Use the bundled skill's default vault path (`/config/Documents/Obsidian Vault` here) unless a real requirement calls for an override; package installation alone is not completed vault setup. See `references/headless-note-vault-cli.md` for selection, installation, Proton Pass credential handling, initial sync, and verification.

## Researching Hosted Replacements for TrueNAS Apps

When Luke asks whether a user-facing TrueNAS app can move to hosted SaaS, treat privacy architecture as a technical property, not a marketing adjective:

- Distinguish true client-side **zero-knowledge/E2EE** from encryption at rest, EU hosting, no-ad policies, and promises of limited staff access.
- Never describe ordinary managed hosting as “as private as self-hosting” when the operator controls the application runtime, database, backups, or encryption key.
- For genuine E2EE, verify separately whether content and meaningful app metadata (filenames, tags, EXIF/location, notebook names) are encrypted; still disclose residual account/network/billing/storage metadata.
- Prefer official pricing, privacy, cryptography, and feature-limit pages. Include billing cadence, currency, free-tier limits, and “from” resource-pricing caveats.
- Evaluate the functional loss as well as privacy: LAN-only reachability, NAS/external libraries, server plugins, P2P behavior, AI subprocessors, or reduced monitoring/widgets.
- Report a compact comparison table and a short verdict that clearly separates true ZK-E2EE candidates from policy-based managed plaintext.

See `references/truenas-hosted-app-alternatives.md` for the reusable workflow, privacy taxonomy, dynamic-pricing research fallback, and the 2026-08-06 market snapshot for Notesnook, PikaPods, Ente, Karakeep Cloud, Start.me, Filen, and Carrd.

For infrastructure/helper retirement specifically, use `references/truenas-app-retirement-hosted-alternatives.md`. It begins with dependency elimination, classifies every helper as delete/conditional/retain-workload, identifies roles that inherently require a trusted local endpoint, and records the dated August 2026 official pricing/privacy evidence for 9Router, TrueNAS/HexOS, notifications, RSS/YouTube, access/IAM, backups, DNS, Proton Bridge, pgAdmin, and AList. Re-check pricing before use.

## TrueNAS ACME Certificate Renewal
When Luke asks to renew TrueNAS certificates, use the TrueNAS middleware job directly and verify both job state and certificate dates:

1. SSH to the NAS using the established host/key from memory, adding a scoped known_hosts file if needed.
2. Inspect certificates first: `midclt call certificate.query` and summarize `id`, `name`, `acme`, `until`, `renew_days`, CN, and SAN without printing private keys or token values.
3. Run renewal as a job: `midclt call -j -jp description certificate.renew_certs`.
4. Verify after the run with `certificate.query` and recent `core.get_jobs` filtered to `certificate.renew_certs`.
5. If Cloudflare DNS challenge fails with `Cannot use the access token from location: <WAN IP>`, interpret it as an IP-restricted Cloudflare token: the token must allow the NAS/home WAN IP or be replaced with a valid DNS-edit token. Do not treat this as a TrueNAS bug or keep retrying unchanged.

See `references/truenas-acme-renewal.md` for the command pattern and the Cloudflare IP-restriction failure signature.

## Codex on an always-on TrueNAS/Linux host

When Luke wants a Hermes-like NAS agent through the ChatGPT app, treat Codex Remote as a separate host-agent migration: inspect the existing user installation and app-server first; place personal skills under `~/.agents/skills/` (not the internal `~/.codex/skills/.system` tree); use concise global `~/.codex/AGENTS.md` guidance; verify both through `codex debug prompt-input`; and keep app-server transport on SSH/local Unix sockets. Skills do not carry Hermes sessions, Mem0, MCP credentials, cron, or gateway integrations, so inventory and recreate those selectively.

If a manually started app server blocks managed bootstrap, verify that no rollout is active, terminate only the exact matched unmanaged process after scope approval, then use Codex's own `app-server daemon bootstrap --remote-control` and verify the managed daemon before generating a short-lived mobile pairing code. See `references/codex-truenas-remote-control.md` for the validated reconnaissance, skill mirroring, Memories, unmanaged-to-managed conversion, pairing, security, and smoke-test workflow.

## T3 Connect on an always-on TrueNAS host

Use T3's official user-systemd service model with its persistent base directory on the Apps pool and the local listener restricted to loopback. For a root-owned service, enable user lingering. If `npx t3 service install` fails because `node-pty` cannot compile on the appliance host, do not add a host build toolchain: build the runtime in a temporary compatible Debian/glibc container using the same Node release and architecture, copy it into the persistent base, and point the systemd unit's `PATH` at that Node/runtime.

Complete `t3 connect link --headless` in a durable interactive session, treat its challenge URL and one-time code as transient secrets, restart the service after authorization, and require a provisioned environment link and relay—not merely a stored credential. See `references/t3-connect-truenas-host-service.md` for the verified deployment and health checks.

## TrueNAS App Deployment Preference
When deploying apps on Luke's TrueNAS SCALE host, prefer approaches in this order:

### TrueNAS AdGuard DNS IP vs Traefik App IP
On Luke's TrueNAS host, distinguish the DNS service IP from the Traefik app-routing IP before changing DNS/app records:

- If Luke asks for the DNS server to be `192.168.1.157`, update the TrueNAS-managed `adguard-home` app `network.dns_port.host_ips` via `midclt call -j app.update`, not rendered compose files.
- Do **not** blindly change app hostname rewrites from the private app wildcard/route host to the NAS UI address: on this host, the private context distinguishes Traefik's address from the TrueNAS nginx/UI address.
- If TrueNAS Apps show Docker DNS failures such as `lookup ... on 127.0.0.11:53: server misbehaving` or cloudflared resolves a private internal origin to public Cloudflare IPs, check the **TrueNAS host** resolver and the actual AdGuard published listener together. The safe invariant is: `midclt call network.configuration.config.nameserver1` must point at the IP where the `adguard-home` app actually publishes port 53. Resolve exact domains and addresses from `~/.agents/private-context.md`. After changing host DNS or app DNS binding, redeploy/restart affected apps so containers regenerate `/etc/resolv.conf`.
- Verify separately: `dig @192.168.1.157 <host> A` for DNS reachability, and `curl --resolve <host>:443:192.168.0.2 https://<host>/` for Traefik routing.
- See `references/truenas-adguard-dns-and-traefik-ips.md` for the safe update command pattern and verification checklist.
- See `references/truenas-docker-dns-recovery.md` for the Authelia/Cloudflared/Traefik outage recovery pattern when bad host DNS propagates into Docker's embedded resolver.
- See `references/truenas-cloudflared-adguard-dns-origin-resolution.md` for the private photo-service class: a cloudflared internal origin resolves publicly because TrueNAS/Docker DNS points at the wrong AdGuard listener.
- See `references/truenas-plex-docker-dns-recovery.md` for the Plex-specific pattern: local Plex port healthy but MyPlex/remote unavailable because the container still has stale Docker `ExtServers`; verify container `plex.tv` DNS and redeploy Plex/related apps through TrueNAS.
- See `references/truenas-ninerouter-9router-maintenance.md` for Luke's `ninerouter` / 9Router custom app update pattern: migrate away from old copied `/app` runtime mounts, use the official `decolua/9router:latest` image, preserve `/app/data`, and verify `/api/version` plus the private route domain from the private context.

See `references/truenas-custom-app-cli-registration.md` for the complete manual registration + Dockge-to-Custom-App migration procedure (including the exact `/mnt/.ix-apps/app_configs/<name>/` structure, python calls to `setup_install_app_dir`/`update_app_config`/`update_app_metadata`/`compose_action`, ix- prefix handling, and the proton-bridge case that drove the pattern). Use this when `midclt app.create` is restricted.

1. Official/native TrueNAS Apps from the catalog.
2. Custom TrueNAS Apps created through the TrueNAS Apps UI.
3. Custom app YAML / Docker Compose only when the first two do not fit.

Deployments should remain visible/manageable through the TrueNAS UI whenever possible. Avoid standalone compose projects that TrueNAS cannot see unless Luke explicitly asks for that style.

For SCALE custom Compose apps, create/update through middleware instead of manual `docker compose` so the app appears in the UI:

```bash
# create
midclt call -j app.create '{"app_name":"<name>","custom_app":true,"custom_compose_config_string":"<compose-yaml-string>"}'

# update existing custom compose
midclt call -j app.update <name> '{"custom_compose_config_string":"<compose-yaml-string>"}'
```

Use project name `ix-<app>` if an updater container must rebuild via the Docker socket, e.g. `docker compose -p ix-<app> -f /compose/docker-compose.yml up -d --build <service>`, so it updates the TrueNAS-managed Compose project rather than creating a standalone one.

### TrueNAS Traefik App Exposure
For exposing TrueNAS Apps through Luke's Traefik app, prefer a small dedicated file in `/mnt/Apps/Applications/traefik/dynamic/` over editing a large shared route file. Verify DNS, Traefik route, TLS certificate, and HTTPS response end-to-end.

When a hostname is outside the existing wildcard certificate SANs, issue a TrueNAS ACME cert for that hostname, copy the resulting `.crt`/`.key` from `/etc/certificates/` into `/mnt/Apps/Applications/traefik/certs/`, reference it from the dynamic file, and touch the dynamic YAML to force Traefik's file provider to reload. Remember that `certificate.create` and `certificate.delete` are job methods; use `midclt call -j ...` for ACME creation and CSR cleanup. See `references/truenas-traefik-app-routing.md` for the route/cert/sync pattern and verification commands.

For custom or self-hosted multi-container services on TrueNAS SCALE:

- Target the dedicated Apps pool at `/mnt/Apps/Applications/<service>` for app files and persistent data unless the TrueNAS app's UI-generated storage paths dictate otherwise.
- Use bind mounts on ZFS datasets/directories instead of Docker named volumes where possible. This ensures native TrueNAS storage management, snapshots, and permissions.
- Expose only the necessary app ports; keep internal services such as Postgres and Redis private to the app network or bound to localhost when possible.
- Luke's current exposure pattern is Traefik as a TrueNAS app bound to `192.168.0.2:80/443`, Docker provider with `exposedByDefault=false`, external network `traefik_proxy`, app-level Traefik labels plus dynamic config files in `/mnt/Apps/Applications/traefik/dynamic/*.yml`.
- Use `authelia@file` / Authelia forwardAuth for private routes unless an app intentionally handles public auth itself; Authelia is backed by LLDAP. Cloudflared provides tunnel ingress without publishing app ports directly.
- Fix common container permission issues immediately (e.g. mounted entrypoint/init scripts must be readable/executable by the container user).
- Ensure passwords in app environment blocks exactly match connection URIs used by dependent services.
- TrueNAS `pool.snapshottask.create` rejects a `description` field; use only accepted fields such as `dataset`, `recursive`, `exclude`, `lifetime_value`, `lifetime_unit`, `naming_schema`, `schedule`, `enabled`, and `allow_empty`.

### TrueNAS Apps pool space and Backrest backups

When Luke reports the Apps pool / apps folder near full, follow `references/truenas-apps-pool-space-reclaim.md` (inventory → Docker unused-image prune first → verify mounts before deleting leftovers / legacy datasets).

When Luke asks about Immich restic, missing backups, or Backrest health, follow `references/truenas-backrest-restic-path-health.md`. **Immich usually already has a plan** — inspect container mounts and process logs before creating another. After reclaim or Backrest upgrades, re-verify `/host/Media` and real `/host/ix-app-mounts` binds.

### qbit_manage tracker retention and orphan review

When changing private-tracker minimum seed times, first mirror the existing tracker-tag/share-limit convention, cover alternate announce hosts, and distinguish the tracker rule's category scope from the separately enumerated `nohardlinks` categories. A universal tracker rule omits `categories:`, but qbit_manage hard-link checks still require every real qBittorrent category explicitly; preserve a manual `keep` override unless Luke directs otherwise.

When qbit_manage reports a large orphan set, do not raise the safety threshold or infer that the data is disposable. Compare every candidate against all live qBittorrent file manifests, check same-name/size near matches, and inspect device/inode/link count to distinguish stale download-only files from download-side links whose media-library hard links remain valid. Keep this audit read-only until cleanup is separately approved.

See `references/truenas-qbit-manage-retention-and-orphan-forensics.md` for the full backup/edit/reload verification flow, multi-host tracker tagging, category-enumeration pitfall, API manifest comparison procedure, hard-link proof, and concise reporting template.

### qBittorrent archive → RomM PS3 library imports

For completed PS3 scene archives, discover qBittorrent and RomM paths from live container mounts, validate every multipart RAR volume, distinguish a JB/folder payload from an existing ISO, and retain the source in place for seeding. Convert folder games with PS3-aware `makeps3iso` tooling rather than generic ISO utilities, publish atomically into the live `roms/ps3` directory, then run a PS3-scoped RomM scan and verify the exact database row, title match, size, metadata IDs, and artwork. RomM filesystem and scheduled rescans may both be disabled, so a successful file copy is not proof of ingestion. See `references/truenas-romm-ps3-imports.md` for the validated disposable-Docker workflow, the `makeps3iso` auto-appended-extension pitfall, internal RQ scan fallback, cleanup, and verification checklist.

This is the preferred native/manageable pattern the user expects for TrueNAS infrastructure.

### Assessing hosted replacements for TrueNAS apps

When Luke asks for hosted or subscription alternatives to TrueNAS media/library/game apps, apply a strict architecture test: TLS, GDPR, private tenancy, at-rest encryption, or a staff non-access policy are not self-hosting-equivalent if the provider controls compute/storage or the running server can decrypt content. Identify the exact function, price storage/GPU/bandwidth separately, distinguish managed-same-app from partial SaaS substitutes, avoid acquisition automation when the *Arr suite is excluded, and say **no equivalent exists** where appropriate. Prefer a compact table with official URLs and an explicit equivalence verdict. See `references/truenas-hosted-privacy-alternatives.md` for the reusable workflow, August 2026 research leads, and functional caveats.

## Home Assistant Config and File Access (SSH Add-on)

Luke's explicit preference is to keep the **SSH & Web Terminal add-on disabled by default** and only enable it temporarily ("as needed") when direct read/write access to files under `/config` (e.g. automations.yaml and split files, configuration.yaml includes, etc.) is required.

See `references/ha-ssh-addon-temporary-access.md` for the detailed workflow and the key limitation discovered in this session: the tokens available to Hermes (long-lived HASS_TOKEN and SUPERVISOR_TOKEN/HASSIO_TOKEN) only allow regular HA API access. Supervisor/hassio addon management endpoints return 401 Unauthorized or 403 Forbidden. `ha_call_service` for the hassio domain is blocked. Therefore the agent cannot self-enable the add-on via API — the user must perform the UI toggle when file work is needed, then disable it afterward.

Additional notes:
- HA itself is not running as a TrueNAS app (no entry in `midclt call app.query` on 192.168.1.157; resolves to 192.168.1.98 from the Hermes container).
- Prefer the temporary manual enable pattern over persistent authorized keys or always-on SSH.

This is a hygiene rule for the HA portion of the stack.

## References
- `references/hermes-container-weekly-maintenance.md` — concrete execution log + recipes from cron runs on the HAOS Hermes container (inspection commands, npm prefix update, **kagi-cli glibc pin**, Kagi MCP wrapper+HOME + auth sync, summarize MCP vs subscriber CLI, smoke tests, caches, hermes-update/gateway approval behavior, git dirty handling, no-sudo observation, final report template). **2026-07-05 follow-up execution:** Luke-directed fix of cron report items (jobs.json paths, linuxbrew tmp reclaim, update+cherry-pick, MCP adapter, add-on gateway restart). **2026-07-05 cron run:** 0.14.1 glibc break → pin 0.11.0; `hermes mcp add` for config.yaml. **2026-06-21:** native typed schemas; `file_safety.py` conflict fix.
- `references/kagi-mcp-schema-probe.py` — Tirith-safe schema probe script (no shell pipes); exit 1 if the five required tools lack typed properties.
- See `references/hermes-harness-boundary.md` for the specific incident that established the Hermes harness rule.
- See `references/proxmox-readonly-recon.md` for read-only Proxmox reconnaissance steps and Luke's current PVE topology snapshot.
- `references/truenas-backrest-restic-path-health.md` — Backrest/restic: empty `_backrest-view` ix-app-mounts stub; Immich Media mount failure (top-level `additional_storage` ignored; use `storage.additional_storage`); host-eval secrets + `docker exec restic` (no python3 in image); midclt app.update Extra inputs pitfall; plan gaps (odysseus, HA); FUTO restore drill; NFSv4 ACL for uid 568.
- `references/truenas-apps-pool-space-reclaim.md` — Apps pool near full: Docker image prune first; karakeep/plex-stage leftovers; legacy Immich `app_mounts` destroy only after live mounts verified; snapshot holdback.
- `references/netbird-bmc-work-pc-dual-homed.md` — generic diagnosis for NetBird routed-network instability when Wi‑Fi and Ethernet are both active.
- `references/hermes-cron-creation.md` — correct `hermes cron create` usage, flags, deliver=local pattern, skill attachment, self-contained prompts, and the generic-cronjob-tool pitfall (for hygiene/monitoring/maintenance jobs). Cross-references the himalaya email-scan example.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update its canonical package under `~/.agents/skills/` when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Make the smallest evidence-backed edit, do not record secrets or transient state, and do not infer a durable preference from one request. Follow the `personal-skill-maintenance` skill for the full review and verification workflow.
