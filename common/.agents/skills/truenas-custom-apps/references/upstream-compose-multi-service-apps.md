# Upstream Docker Compose → TrueNAS Custom App

Pattern for projects that ship `docker-compose.production.yml` (or similar) and a prebuilt image — no clone/build on the NAS. Validated with FUTO Notes sync server (Jun 2026); reuse for any server+database compose stack.

## When to use

- Upstream README says: curl compose + `.env`, `docker compose up -d`
- One or more services with `depends_on` and healthchecks (e.g. app + Postgres)
- Luke wants it in **Apps** as `custom_app`, data under `/mnt/Apps/Applications/<name>/`, and exposed through the private app domain resolved from `~/.agents/private-context.md`

## Workflow (SSH on 192.168.1.157)

1. **Discover** — `curl` raw `docker-compose.production.yml` and `.env.*.example` from upstream (GitLab/GitHub raw URLs). Note required env vars and image registry.
2. **Pull image on NAS** — `docker pull <image:tag>` before registering (surfaces registry/auth issues early).
3. **Data dirs** — `mkdir -p /mnt/Apps/Applications/<name>/data/{blobs,postgres,...}` per compose volume layout.
4. **Secrets on NAS** — generate on the host, never in agent memory long-term:
   - DB password: `openssl rand -hex 32`
   - App admin password: random + hash via upstream’s documented one-shot, e.g.
     `docker run --rm <image> bun dist/index.js hash '<password>'` (FUTO Notes)
   - Write secrets into `user_config.yaml` `environment` lists via a **python** `yaml.dump` on NAS; avoid echoing hashes in chat logs when possible (deliver admin password to user once, suggest Proton Pass).
5. **Compose in ix-apps** — mirror **ninerouter** layout:
   - `user_config.yaml` with `services:` map, `version: "3.0"`
   - Duplicate identical content to `versions/1.0.0/templates/rendered/docker-compose.yaml`
   - `metadata.yaml` at app root, `app.yaml`, `README.md`
   - Multi-service blocks: copy `healthcheck` / `depends_on` from odysseus (e.g. `condition: service_healthy`)
6. **Register** — `midclt call app.metadata.generate` then `midclt call app.query` → `custom_app: true`, state often `STOPPED`.
7. **Start + recovery** — `midclt call app.start <name>`; poll until `RUNNING`. If state stays `STOPPED` and **no** `ix-<name>-*` containers exist:
   ```bash
   docker compose -f /mnt/.ix-apps/app_configs/<name>/versions/1.0.0/templates/rendered/docker-compose.yaml -p ix-<name> up -d
   midclt call app.start <name>
   ```
   Poll again; expect `DEPLOYING` → `RUNNING`.
8. **Traefik** — see `references/traefik-exposure-for-custom-apps.md`. Pick an unused host port (e.g. `ss -tuln`), bind `192.168.1.157:<port>:<container>` for Traefik backend URL.
9. **Verify** — `docker ps`, `curl` LAN port, `curl -I https://<private-app-host>`, and app-specific login/API if documented.

## Port binding on this NAS

| Use case | Host bind |
|----------|-----------|
| Container-to-container only (bridge, internal API) | `127.0.0.1:<port>` |
| Traefik / LAN backend (odysseus, apprise, sync APIs) | `192.168.1.157:<port>` or `0.0.0.0:<port>` per existing app |

Do not assume every service is `127.0.0.1` — match the consumer (Traefik hits NAS IP).

## FUTO Notes–specific notes (example)

- Image: `gitlab.futo.org:5050/futo-notes/futo-notes-server/server:stable`
- Env: `AUTH_MODE=password`, `FUTO_NOTES_PASSWORD_HASH`, `DATABASE_URL` with embedded Postgres password, `TRUST_PROXY=true` when behind Traefik
- App config: Settings → Sync → the private notes host from the private context + admin password
- Data backup: `/mnt/Apps/Applications/futo-notes/data/` (blobs + postgres)

## Upgrade

Change image tag in `user_config.yaml` + `templates/rendered/docker-compose.yaml`, `app.stop` / `app.start`, or `docker compose pull` on project `ix-<name>` then recreate via Apps UI.