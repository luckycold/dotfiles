# Jellyfin: Authelia browser SSO + native third-party clients

Use this pattern when the private Jellyfin host from `~/.agents/private-context.md` is protected by Traefik forwardAuth but native clients must still work.

## Architecture

- Browser shell/default route: `authelia@file` middleware.
- OIDC: Jellyfin SSO-Auth plugin → Authelia confidential client with `two_factor`, PKCE S256, and exact callback.
- Public client discovery endpoints: bypass forwardAuth without a rate limit.
- Native password login: bypass forwardAuth only for `POST /Users/AuthenticateByName`, with a strict rate limit.
- Authenticated Jellyfin calls: bypass forwardAuth only when a Jellyfin token is present in `Authorization`, `X-Emby-Token`, `X-MediaBrowser-Token`, or `api_key` query string.
- Keep the native Jellyfin password as an app-style secret; browser users should use the existing Branding login-disclaimer SSO button.

## Important callback-casing pitfall

SSO-Auth 4.0.0.4 indexes providers case-sensitively. If the XML dictionary key is `Authelia`, the plugin generates:

`https://<private-jellyfin-host>/sso/OID/redirect/Authelia`

Authelia must register that exact URI, including casing. The lowercase callback from generic documentation fails exact redirect matching. Tight repro: call `/sso/OID/start/Authelia` directly on the backend with forwarded host/proto and inspect the authorization redirect's `redirect_uri`.

## Traefik routers

Use a dedicated `dynamic/jellyfin.yml` and remove older duplicate Jellyfin routers/services from shared files.

1. `jellyfin-native-token`, priority 400: token header/query match; no Authelia.
2. `jellyfin-native-login`, priority 350: `Method(POST) && Path(/Users/AuthenticateByName)`; rate limit 5/min, burst 5.
3. `jellyfin-native-public`, priority 300: `/System/Info/Public`, `/System/Ping`, `/health`, `/Branding/Configuration`, `/QuickConnect/Enabled`; no rate limit.
4. `jellyfin-browser-sso`, priority 100: host catch-all with `authelia@file`.

Do **not** put public discovery endpoints under the password-login rate limiter: clients may probe them repeatedly and get false 429s.

## OIDC secret handling

Authelia stores a PBKDF2 digest in `/config/secrets/clients_jellyfin_client_secret`; the Jellyfin plugin needs the corresponding plaintext in `SSO-Auth.xml`. Generate both together using Authelia's `crypto hash generate pbkdf2 --random` command, capture without printing, write the digest to Authelia's secret file, and put the plaintext only into the plugin config. Never print or save the plaintext in logs, memory, skills, or chat.

Back up first. Validate with:

`docker exec ix-authelia-authelia-1 authelia config validate --config /config/configuration.yaml`

Then restart Authelia and Jellyfin and wait for `/api/health` and `/health`.

## User cleanup

Use the supported Jellyfin API with an existing internal API key to `DELETE /Users/{id}` for explicitly approved users. Also remove stale `CanonicalLinks` entries from `SSO-Auth.xml`. Keep the intended canonical account (currently `lucky`).

## Verification

- `/` → 401/redirect to Authelia.
- `/Users/Me` without token → Authelia.
- `/Users/Me` with fake token → Jellyfin 401, no Authelia redirect.
- `/System/Info/Public` ten times → all 200.
- Seven wrong logins for a nonexistent user → five 401s then 429s.
- Existing valid API token through public host can list users.
- `/sso/OID/start/Authelia` → Authelia authorization endpoint with exact callback; Authelia authorization then redirects to its login flow rather than rejecting client/redirect.
- `midclt app.query` shows Jellyfin, Authelia, Traefik, Cloudflared, and LLDAP RUNNING.
- Traefik logs show no Jellyfin route parse errors.
