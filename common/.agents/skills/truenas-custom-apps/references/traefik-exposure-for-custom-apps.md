# Traefik exposure for TrueNAS custom apps (Luke stack)

Luke’s public surface uses **Traefik** + **Cloudflare** on a private app domain resolved from `~/.agents/private-context.md`. Most browser UIs use **Authelia** middleware; some **native/mobile API clients** must reach the backend without Authelia because they use the app’s own auth.

## File location

Per-app dynamic config (preferred for new services):

```
/mnt/Apps/Applications/traefik/dynamic/<app-name>.yml
```

Traefik picks up file provider changes automatically (no restart required in normal operation).

## Template (HTTPS, no Authelia — API / sync clients)

Use when the service authenticates clients itself (e.g. FUTO Notes `POST /api/auth/password/login`):

```yaml
http:
  routers:
    <app-name>:
      rule: "Host(`<private-app-host>`)"
      entryPoints: [websecure]
      tls: {}
      priority: 100
      service: <app-name>

  services:
    <app-name>:
      loadBalancer:
        servers:
          - url: "http://<private-backend>:<host_port>"
        passHostHeader: true
```

## Template (HTTPS + Authelia — browser admin UIs)

Match `routes.yml` / `odysseus.yml` pattern when only humans use a browser:

```yaml
http:
  routers:
    <app-name>:
      rule: "Host(`<private-app-host>`)"
      entryPoints: [websecure]
      tls: {}
      priority: 100
      middlewares: [authelia]
      service: <app-name>

  services:
    <app-name>:
      loadBalancer:
        servers:
          - url: "http://<private-backend>:<host_port>"
        passHostHeader: true
```

## Decision rule

| Client | Authelia on route? |
|--------|-------------------|
| Mobile/desktop app with server password or API token | **No** — Authelia breaks non-browser auth flows |
| Browser-only admin UI Luke expects behind SSO | **Yes** — consistent with apprise, odysseus, etc. |

When Authelia is skipped, rely on app auth + TLS; mention that in the handoff to Luke.

## App env behind proxy

Set upstream `TRUST_PROXY=true` (or equivalent) when the app rate-limits or logs by client IP and reads `X-Forwarded-For`. Only when the proxy is trusted (Traefik on LAN).

## AList-specific public exposure checks

Before bypassing Authelia for AList:

1. Run a maintained AList release. Versions before **3.57.0** are affected by CVE-2026-25160 (critical insecure outbound TLS defaults) and CVE-2026-25161 (authenticated path traversal). Pin a current official `xhofe/alist:<version>-aria2` image when Aria2 is needed.
2. **Check the persisted `data/config.json` after upgrading.** An older install can retain `"tls_insecure_skip_verify": true` even though the patched release changed the default. Back up the config, set it to `false`, restart AList, and verify it stayed false. Merely changing the image does not remediate a persisted insecure value.
3. Verify the live database/settings without printing hashes, TOTP secrets, storage credentials, or driver `addition` JSON: guest disabled, registration disabled, indexing disabled, `sign_all=true`, and only intended users active.
4. Do not assume 2FA is active because AList supports it. Check whether the intended user's `otp_secret` is actually populated. Also note that WebDAV uses the normal AList username/password and does **not** gain TOTP protection; prefer a dedicated non-admin user with only the WebDAV/file permissions the client needs.
5. For a public Cloudflare route, a dedicated higher-priority Traefik router without Authelia is a recoverable override. Add a per-client rate limiter using trusted `CF-Connecting-IP` rather than the tunnel/container source IP, then verify both normal requests and actual `429` responses under a bounded burst test.
6. Verify externally (not only through split DNS): browser login page loads, unauthenticated `/api/me` remains denied by AList, and `/dav/` returns AList's `401` with `WWW-Authenticate: Basic realm="alist"`.
7. **AList OIDC with Authelia uses `client_secret_basic`.** AList v3's Go `oauth2.Config.Exchange` authenticates to the discovered token endpoint with HTTP Basic. The Authelia `alist` client must therefore use `token_endpoint_auth_method: client_secret_basic`, not `client_secret_post`. The exact failure signature is a successful authorization redirect followed by Authelia logging that the request used `client_secret_basic` while the registration only allows `client_secret_post`. Back up Authelia's config, change only the AList client, validate with `authelia config validate --config /config/configuration.yaml --config.experimental.filters template`, then cycle Authelia through TrueNAS middleware. Verify safely by POSTing an intentionally invalid authorization code with AList's real client ID/secret over HTTP Basic: the expected result is `invalid_grant` (client accepted and code validation reached), not `invalid_client` or `Client authentication failed`. Never print the client secret.
8. Keep both AList callback URIs registered in Authelia when using non-compatibility mode: `/api/auth/sso_callback?method=sso_get_token` for login and `...?method=get_sso_id` for account binding. Confirm `/api/auth/sso?method=<method>` redirects to Authelia's `/api/oidc/authorization` with the exact corresponding callback and a non-empty state.
9. **Provision each intended OIDC user in AList when `sso_auto_register=false`.** Prefer AList's admin API/UI. If no admin token is available and a carefully scoped SQLite fallback is necessary, first make an online `.backup` of `data.db`, then create a non-admin row in `x_users` with `role='[3]'` (General User), `disabled=0`, least-privilege `permission` (use `0` for normal read-only browsing), and `sso_id` exactly matching the claim selected by `sso_oidc_username_key`. Give the local-password fields an unguessable random hash/salt rather than copying another account; this makes the account SSO-only. For Authelia backed by LLDAP, prefer `sso_oidc_username_key=preferred_username` and use the stable LDAP `user_id` as `sso_id`; Authelia advertises this standard claim under the `profile` scope. Do not use `name` as the identifier unless every LDAP user has a non-empty display name: Authelia can omit `name` for such users, and AList then reports that it cannot find the username from the OIDC provider. Restart AList, run `PRAGMA integrity_check` on both live and backup databases, and re-query the row. If Authelia's client policy is `two_factor`, independently confirm that the LDAP user has an enrolled Authelia TOTP or WebAuthn credential and is not banned. Do not claim an end-to-end login test unless the user actually authenticates; server-side verification proves provisioning and flow readiness, not possession of the user's factor.

## Karakeep public-client exposure checks

Karakeep's mobile/browser extensions and API clients must reach Karakeep directly; an Authelia forward-auth middleware in front breaks those clients. When Karakeep already delegates interactive login to Authelia through its own NextAuth/OIDC provider:

1. Add a dedicated higher-priority Traefik router for the whole Karakeep host with **no** forward-auth middleware. A persistent `karakeep-public.yml` under the dynamic directory at priority `200` is preferable to modifying generated lower-priority protected-route files.
2. Confirm the live Karakeep container has the expected `NEXTAUTH_URL`, `OAUTH_PROVIDER_NAME=Authelia`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`, and `OAUTH_WELLKNOWN_URL` values. Prefer `DISABLE_PASSWORD_AUTH=true` when OIDC is the intended interactive login; never print the secrets.
3. Confirm Authelia has the Karakeep client, exact callback `https://<host>/api/auth/callback/custom`, scopes `openid email profile`, an appropriate MFA policy, and the token endpoint auth method Karakeep actually uses (normally `client_secret_basic`).
4. Verify externally after Traefik reload:
   - `/` stays on the Karakeep host and finishes at `/signin`, not `auth.<domain>`.
   - `/api/v1/bookmarks` without credentials returns Karakeep's own `401 Unauthorized`, with no `Location` header to Authelia.
   - `/api/auth/providers` lists the custom OAuth provider as Authelia.
   - Fetch `/api/auth/csrf`, then POST it to `/api/auth/signin/custom`; the returned URL must target Authelia's authorization endpoint with the Karakeep client ID and exact callback URI.
5. A successful OIDC initiation plus app-origin API `401` proves the routing and identity integration are wired correctly. A complete user login or API-key request still requires possession of that user's factor/key; do not fabricate that test.

## Verification

```bash
curl -sI "https://<private-app-host>/"
# Optional: app login endpoint per upstream docs
```

Confirm `midclt call app.query` shows `RUNNING` and `docker ps` shows healthy containers for `ix-<app-name>-*`.