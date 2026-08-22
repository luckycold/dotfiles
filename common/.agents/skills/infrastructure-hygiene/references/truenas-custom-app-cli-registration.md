# TrueNAS Custom App CLI Registration and Dockge Migration

Session-derived pattern for Luke's TrueNAS SCALE host when registering Custom Apps (or migrating Dockge/manual compose stacks) via SSH/CLI because `midclt call app.create` (and `app.custom.create`) returns validation errors and is restricted/blocked for custom apps.

This was the technique used to promote the existing `proton-bridge` (shenxn/protonmail-bridge) from a Dockge stack into a first-class UI-visible Custom App alongside `ninerouter` and `odysseus`.

## When this pattern applies
- Fresh creation of a simple single-service Custom App (e.g. mail bridge, routers, small services) over SSH.
- Migration of an existing Dockge stack or raw `docker compose` project so it becomes manageable through the TrueNAS Apps UI and `midclt call app.*` (start/stop/update/query/config).
- The host has the restriction on `app.create` for `custom_app: true` (observed 2026-06; ninerouter was previously updated via direct `user_config.yaml` edit + `app.update` instead of create).

Prefer the documented order in the parent skill: official catalog apps > Custom Apps created through the TrueNAS web UI > this manual CLI registration only when the first two are not viable.

## Target deployment shape (after registration)
- App name in TrueNAS: `proton-bridge` (or your `<app_name>`).
- Container name: `proton-bridge` (explicit `container_name` in compose keeps it short and friendly).
- Project label: `ix-proton-bridge` (TrueNAS always prefixes with `ix-` for its internal compose projects).
- Data: `/mnt/Apps/Applications/proton-bridge/data` (or `/data/...` subdir) bind-mounted for the app.
- Ports: always bind to `127.0.0.1` only for local-only inter-app use (e.g. `127.0.0.1:1143:1143` for IMAP).
- Type: `custom_app: true`, version `1.0.0`, `human_version: "1.0.0_custom"`.
- Appears in `midclt call app.query | jq '... | select(.custom_app)'` and the web UI Apps list.
- Lifecycle managed by TrueNAS middleware (not standalone docker compose or Dockge).

## Filesystem structure to create (exact match to ninerouter/odysseus)
```bash
/mnt/.ix-apps/app_configs/<app_name>/
├── metadata.yaml
└── versions/
    └── 1.0.0/
        ├── app.yaml
        ├── user_config.yaml          # the "services" dict only
        ├── README.md
        └── templates/
            └── rendered/
                └── docker-compose.yaml   # identical to user_config.yaml
```

- `metadata.yaml`: `"custom_app": true`, `"human_version": "1.0.0_custom"`, `"version": "1.0.0"`, `"migrated": false`, `"portals": {}`, `"notes": null`, plus full `"metadata"` block from `get_version_details()`.
- `app.yaml`: the inner catalog_reader custom-app metadata (title "Custom App", description about user-provided compose, train "stable", etc.).
- `user_config.yaml` and `rendered/docker-compose.yaml`: exactly `{"services": {"<service-name>": { "image": "...", "container_name": "...", "restart": "unless-stopped", "ports": ["127.0.0.1:host:container", ...], "volumes": ["/mnt/Apps/Applications/<app>/data:/target", ...], "environment": ["TZ=..."] }}}`
  - Note: no top-level `version:` key; just the services object. This is what the custom app renderer expects and what `app.config` returns.
- README.md: the generic custom app placeholder text.

Data directories live under `/mnt/Apps/Applications/<app_name>/data` (ZFS dataset-friendly, snapshotable). For proton-bridge the bridge config lives at `data/` (not `config/`) to match the convention used by ninerouter (`9router/data`) and odysseus.

## Registration recipe (direct middleware calls — the reliable path when midclt create is blocked)
Use an SSH session to root on the NAS. Run a Python one-liner or script that imports the internal modules and replicates exactly what `app.custom.create` does internally:

```python
import os
import sys
import yaml
from datetime import datetime

sys.path.insert(0, "/usr/lib/python3/dist-packages")

from middlewared.plugins.apps.ix_apps.setup import setup_install_app_dir
from middlewared.plugins.apps.ix_apps.lifecycle import update_app_config, update_app_metadata
from middlewared.plugins.apps.compose_utils import compose_action
from catalog_reader.custom_app import get_version_details

app_name = "proton-bridge"
version = "1.0.0"

compose_config = {
    "services": {
        "proton-bridge": {
            "image": "shenxn/protonmail-bridge:latest",
            "container_name": "proton-bridge",
            "restart": "unless-stopped",
            "ports": [
                "127.0.0.1:1143:1143",
                "127.0.0.1:1025:1025"
            ],
            "volumes": [
                "/mnt/Apps/Applications/proton-bridge/data:/root/.config/protonmail-bridge"
            ],
            "environment": [
                "TZ=America/Los_Angeles"
            ]
        }
    }
}

os.makedirs(f"/mnt/Apps/Applications/{app_name}/data", exist_ok=True)

setup_install_app_dir(app_name, version, custom_app=True)
update_app_config(app_name, version, compose_config, custom_app=True)
version_details = get_version_details()
update_app_metadata(app_name, version, version_details, custom_app=True)
compose_action(app_name, version, "up", force_recreate=True, remove_orphans=True)
```

After the script:
- `midclt call app.metadata.generate` (regenerates the collective metadata so `app.query` picks it up).
- Verify immediately:
  ```bash
  midclt call app.query | jq -r '.[] | select(.name=="proton-bridge") | {name, custom_app, state, version, active_workloads}'
  docker ps --filter name=proton-bridge --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  docker inspect proton-bridge --format '{{.Config.Labels}}' | grep -E 'compose.project|ix-'
  ```

The `compose_action` call internally does `docker compose -p ix-<app_name> -f <rendered-path> up ...`

## Pre-steps for migration from Dockge / raw compose
1. Stop and remove the old unmanaged containers/project (keeps volumes):
   ```bash
   docker compose -p proton-bridge -f /mnt/Apps/Applications/dockge/stacks/proton-bridge/compose.yaml down --remove-orphans
   # or simply: docker stop proton-bridge && docker rm proton-bridge
   ```
2. (Optional but recommended) Remove the old Dockge stack definition after successful registration so it disappears from the Dockge UI:
   ```bash
   rm -rf /mnt/Apps/Applications/dockge/stacks/proton-bridge
   ```
3. Ensure the data dir exists and has correct ownership for the image (the container will often run as uid 1000 or root; the volume bind handles it).

## Proton-bridge (shenxn/protonmail-bridge:latest) specifics
- The image's default entrypoint runs socat forwards (container:25→bridge:1025, 143→1143) + `protonmail-bridge --cli` via a fifo (to keep it from exiting on EOF).
- It **requires** a one-time interactive initialization for the `pass` password manager + GPG + Proton login:
  ```bash
  # After the app is registered but before (or after a clean) start
  docker run --rm -it \
    -v /mnt/Apps/Applications/proton-bridge/data:/root/.config/protonmail-bridge \
    shenxn/protonmail-bridge:latest /protonmail/entrypoint.sh init
  ```
  - This does `gpg --generate-key`, `pass init`, then launches the CLI login flow.
  - Supply your Proton email, password, and 2FA code when prompted.
  - The CLI will output the bridge username (usually your email or a fixed "protonmail") and a long bridge password. These are the credentials other apps use.
- After init, start the managed app: `midclt call app.start proton-bridge` (or via UI).
- Common first-run symptom (until init): "Proton Mail Bridge is not able to detect a supported password manager (secret-service or pass)."
- The published ports on the container are the bridge's 1025/1143 (standard 25/143 are only exposed internally via socat).
- TZ and the exact volume path must match what the bridge expects.

Once running and initialized, other containers on the same host (or the Odysseus app, ntfy, etc.) can reach IMAP on 127.0.0.1:1143 and SMTP on 127.0.0.1:1025 using the bridge credentials. No external exposure.

## Verification checklist (post-registration)
- `midclt call app.query` shows the app with `custom_app: true` and correct state.
- `midclt call app.config <name>` returns the exact services dict you supplied.
- `docker inspect ... | grep com.docker.compose.project` shows `ix-<name>`.
- Container name is the short friendly name you set.
- Data is under `/mnt/Apps/Applications/<name>/data`.
- No leftover Dockge stack for the same service.
- For proton: no password-manager error in `docker logs proton-bridge` after init + start; `docker exec ... protonmail-bridge --cli info` works.

## Pitfalls & hard-won lessons
- **midclt create is blocked on this host** — do not waste time on `midclt call app.create '{"app_create": {"custom_app":true, "app_name":..., "custom_compose_config":...}}'` or the flat key:value style. Use the direct python calls above.
- Project name must be `ix-` prefixed for `list_resources_by_project` + `get_app_name_from_project_name` (which does `project[len("ix-"):]`) to correctly attribute workloads back to the app name. Running under a bare "proton-bridge" project (as the old Dockge did) breaks the mapping.
- Always down the old project before the `compose_action "up"` when the container_name is the same; otherwise name conflicts occur.
- `user_config.yaml` and the rendered file must be **exactly** the services object; the custom app machinery does not expect a full `version: '3.8' services: ...` compose file.
- After writing the files + compose up, you **must** run `midclt call app.metadata.generate` or the app may not appear in queries/UI until a reboot or full apps rescan.
- For complex multi-service apps (see Odysseus below), the web UI creation is often cleaner because it can include source trees, updater containers, and multiple rendered templates. Use manual registration primarily for simple services.
- Data dir ownership often becomes 1000:1000 from the container; this is normal and the bind mount still works.
- Do not leave the old Dockge stack directory around — it causes confusion in the Dockge UI even after the container has moved under TrueNAS management.
- The `setup_install_app_dir` call creates the directories and basic files; the update_* calls overwrite the important yaml bits.

## Odysseus context (the multi-service custom app on this host)
Odysseus (the self-hosted AI workspace from the PewDiePie video, deployed on this NAS as the `odysseus` custom app) was created through the TrueNAS web UI (not this manual path). It uses:
- Main service + chromadb, ntfy, searxng.
- An `updater` container that watches source and rebuilds.
- `COMPOSE_PROJECT_NAME: ix-odysseus` in the updater env.
- Source and compose dirs under the app data.
- External access through the private app host from `~/.agents/private-context.md` (Cloudflare → Traefik → Authelia).

The manual registration pattern above is not needed for it, but the same inspection commands (`midclt call app.query`, ls of app_configs, docker labels) apply.

## Cross-references
- `references/truenas-ninerouter-9router-maintenance.md` — the simpler "edit user_config.yaml then app.update" pattern used for the 9Router custom app (no full re-registration needed for image changes).
- Parent `infrastructure-hygiene` SKILL.md — deployment preference order, why we keep apps UI-visible, data dir conventions, midclt job patterns, and TrueNAS Traefik/ACME details.
- General TrueNAS custom app hygiene lives here; specific app maintenance lives in per-app reference files.

This pattern keeps the infrastructure conventional, UI-manageable, and recoverable.