# Home Assistant SSH Add-on and Config File Access Patterns (Temporary Enable)

## User Preference (Standing Rule)
Luke wants the **SSH & Web Terminal add-on kept disabled by default**. Enable it only "as needed" and only for the duration of direct filesystem work on HA configuration files (`/config/automations.yaml`, split files under `/config/automations/`, `configuration.yaml` includes, scripts, etc.).

**Do not**:
- Set up persistent authorized_keys that leave SSH always available.
- Leave the add-on running with SSH exposed after the task.
- Assume API-driven enable/disable is available.

**Intended workflow**:
1. User manually enables the add-on in the HA UI when file edits are requested (and provides the configured username + the port the add-on exposes).
2. Agent connects via the terminal tool using the established key or password method for that session only.
3. Agent reads (`cat`, `ls`, `grep`), proposes or applies edits (via write_file/patch in the session context or direct commands), verifies.
4. User disables the add-on immediately after.

This keeps exposure minimal and matches Luke's explicit request for "keep the SSH mode disabled... enable it as needed."

## API / Token Scope Limitation
The tokens available to the Hermes container only permit regular Home Assistant REST API access.

Tested endpoints (2026-06):
- Success: `GET /api/config` (returns version 2026.5.4, components, etc.), states, services (including automation.*), ha_list_services, ha_get_state, ha_call_service for non-hassio domains.
- Failure (401 Unauthorized): `GET /api/hassio/addons`, addon info/options, supervisor management paths.
- Failure (403 Forbidden): direct `http://supervisor/addons` and similar.
- `ha_call_service` domain="hassio" is explicitly blocked in the tool for security.

**Conclusion**: Cannot use the API to read current add-on options or toggle the SSH feature programmatically. Manual UI action by the user is required for any enable/disable.

## Additional Context from Recon
- Home Assistant is **not** one of the TrueNAS Apps on 192.168.1.157 (absent from `midclt call app.query` results; earlier `docker ps` on the NAS showed no matching containers).
- From the Hermes container, `homeassistant` resolves to 192.168.1.98 (internal DNS).
- The add-on is the documented, supported path for direct config file access on most HA installs. Direct SSH to the underlying host/VM/LXC (if separately enabled) is an alternative only if the user has set it up outside the add-on.

## Verification Commands (for diagnosing token scope)
```bash
# Should succeed
curl -s -H "Authorization: Bearer $HASS_TOKEN" "http://homeassistant:8123/api/config" | python3 -c '
import sys, json; d = json.load(sys.stdin); print("version:", d.get("version"))
'

# Expect 401 or empty/non-JSON
curl -s -w "\nHTTPSTATUS:%{http_code}\n" -H "Authorization: Bearer $SUPERVISOR_TOKEN" "http://homeassistant:8123/api/hassio/addons" | head -c 100
```

## Related Skills and References
- `proton-pass-cli` (if the add-on config itself stores secrets or keys).
- `truenas-custom-apps` and the broader infrastructure-hygiene stack (for when HA storage paths or related services on TrueNAS are involved).
- Use only for the duration of the file task; always have the user disable afterward.

Update this reference with any new token scope discoveries, alternative file-access add-ons (File Editor, Studio Code Server), or changes in how the add-on exposes its SSH port/username.

## Session Origin
Derived from investigation after the user asked whether the agent could "modify SSH access in the SSH add-on" and "enable it yourself" via the API (June 2026 session). The preference for disabled-by-default was stated explicitly.