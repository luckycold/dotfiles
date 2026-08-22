# ix-apps Custom App Directory Structure and Patterns

Condensed reference from inspection and successful registration of proton-bridge alongside existing ninerouter and odysseus custom apps. Use this when replicating the structure for a new service.

## Standard Directory Tree
```
/mnt/.ix-apps/app_configs/<app-name>/
├── metadata.yaml
└── versions/
    └── 1.0.0/
        ├── app.yaml
        ├── user_config.yaml
        ├── templates/
        │   └── rendered/
        │       └── docker-compose.yaml
        └── README.md
```

(Some older notes list `rendered/` directly under `1.0.0/`; on this NAS, **ninerouter** and **futo-notes** use `templates/rendered/docker-compose.yaml` — keep it identical to `user_config.yaml`.)

- The `versions/1.0.0/` is the active definition for manual custom apps.
- Compose project name used by the system: `ix-<app-name>` (e.g. ix-proton-bridge).
- Persistent data is **never** stored inside the ix-apps tree; always map from `/mnt/Apps/Applications/<app-name>/data`.

## Key Files and Content Patterns

### metadata.yaml
Generated or refreshed with:
`midclt call app.metadata.generate`

Contains app identity, version, and ix-apps bookkeeping. Run this after skeleton creation to make the app discoverable.

### user_config.yaml (most important for edits)
Defines the Docker service(s). Common top-level structure includes a "services" map or direct service block.

**proton-bridge example patterns (local email service):**
- image: shenxn/protonmail-bridge:latest
- ports:
  - "127.0.0.1:1143:1143"   # IMAP for Odysseus and other containers
  - "127.0.0.1:1025:1025"   # SMTP
- volumes:
  - "/mnt/Apps/Applications/proton-bridge/data:/root/.config/protonmail-bridge"
- The image uses /protonmail/entrypoint.sh which handles socat port forwarding + the bridge binary.
- After start: interactive init via `docker exec -it proton-bridge /protonmail/entrypoint.sh init`

**ninerouter (post-update) patterns:**
- image: decolua/9router:latest
- volumes: only the data mount ("/mnt/Apps/Applications/9router/data:/app/data")
- No custom command or working_dir (unlike earlier bun-based version).
- Exposes its own port (e.g. 20128 in prior config) but can be adjusted.

**General rules for this setup:**
- Always prefix host ports with `127.0.0.1:` for local-only shared access.
- Volume source must be the prepared /mnt/Apps/Applications/.../data path.
- Backup before edits: `cp user_config.yaml user_config.yaml.bak-$(date +%Y%m%d%H%M%S)`
- Use python for edits:
  ```python
  import yaml
  with open('user_config.yaml') as f: data = yaml.safe_load(f)
  # modify data['services'] or equivalent
  with open('user_config.yaml', 'w') as f: yaml.dump(data, f)
  ```

### rendered/docker-compose.yaml
The actual compose file consumed by the ix-apps runtime. It should be consistent with the service definition in user_config.yaml. Often created alongside or generated during metadata steps. Direct `docker compose -p ix-<name> -f .../rendered/docker-compose.yaml up -d` can be used as a fallback or verification.

### app.yaml and README.md
- app.yaml: App manifest (name, version, description).
- README.md: Human-readable note, e.g. "Proton Mail Bridge — local IMAP (1143) / SMTP (1025) for use by Odysseus and other NAS containers. Data at /mnt/Apps/Applications/proton-bridge/data. Registered manually due to app.create restrictions."

## Creation Commands (SSH context)
Typical sequence used:
```bash
ssh -i "$NAS_SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$NAS_KNOWN_HOSTS" "$NAS_SSH_TARGET" '
  mkdir -p /mnt/Apps/Applications/proton-bridge/data
  chmod 700 /mnt/Apps/Applications/proton-bridge/data
  rm -rf /mnt/Apps/Applications/dockge/stacks/proton-bridge
  mkdir -p /mnt/.ix-apps/app_configs/proton-bridge/versions/1.0.0
  # then cat > each file or use python to write user_config.yaml
  midclt call app.metadata.generate
  midclt call app.query | jq ".[] | select(.name == \"proton-bridge\")"
  midclt call app.start proton-bridge
'
```

## Verification After Registration
- `midclt call app.query | jq '.[] | select(.name == "proton-bridge") | {name, state, custom_app, version}'`
- `docker ps -a --filter name=proton-bridge --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"`
- Confirm in TrueNAS UI Apps list.
- Test local port from another container (e.g. Odysseus).

## Session-Specific Notes (proton-bridge + Odysseus)
- Goal: Give Odysseus (pewdiepie-archdaemon/odysseus) local email without exposing Proton credentials or the bridge externally.
- Bridge remains STOPPED until files + metadata + start; data dir starts empty.
- Init is one-time interactive; subsequent runs use the stored config.
- After successful init + `protonmail-bridge --cli info`, the output username/password are what get configured inside Odysseus (host 127.0.0.1 or NAS IP from inside the network, ports 1143/1025).
- Always use the proton-pass-agent with reason for locating the original Proton Mail item; never bypass consent.

This reference should be updated (via patch or additional write) whenever a new custom app reveals a variation in the required files or midclt behavior.