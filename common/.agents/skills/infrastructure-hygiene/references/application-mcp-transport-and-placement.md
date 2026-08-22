# Application MCP transport and placement

Use this when connecting Hermes to a self-hosted application that offers an MCP server or an API-backed MCP package.

## Start with the actual goal

Separate three questions before changing infrastructure:

1. **Where is the application/data?** Usually on TrueNAS or another service host.
2. **Where does the MCP process run?** It may run beside the application, inside Hermes, or as a shared network service.
3. **Which transport does the client require?** Local `stdio` and remote Streamable HTTP are different deployment shapes.

Do not assume that “MCP access to the application” means “publish an `/mcp` URL on the application hostname.” If Hermes is the only client and the official MCP package supports `stdio`, the clean default is to run that official package as a Hermes-managed stdio MCP process and point it at the application’s private/LAN API.

## Preferred decision order

### 1. Hermes-only access: direct stdio

Prefer:

```text
Hermes native MCP client
  -> official stdio MCP package
  -> scoped API credential
  -> application private/LAN API
```

Benefits:

- no additional TrueNAS app;
- no reverse-proxy exception;
- no publicly reachable MCP endpoint;
- fewer authentication and transport layers;
- official package remains independently upgradeable and testable.

Pin the package/image version when reproducibility matters. Register it through `hermes mcp add --command ... --env ...`, then run `hermes mcp test <name>` and make a real read-only tool call after MCP reload/restart.

### 2. Shared remote endpoint explicitly required

Only introduce Streamable HTTP when another machine/client genuinely needs a network MCP URL or the user explicitly asks for the MCP server to run on the application host.

If the official release lacks HTTP transport:

- keep the catalog application untouched;
- deploy a separate UI-managed TrueNAS custom app/sidecar for the official MCP process plus a pinned stdio-to-HTTP adapter;
- use a dedicated machine credential at the HTTP edge;
- expose only the MCP path through a higher-priority path router;
- keep the normal human UI under its existing interactive authentication;
- verify initialization, tool discovery, and a read-only call through the public endpoint.

An adapter such as Supergateway is a **transport translator**, not part of Karakeep and not automatically required for MCP. Explain that distinction before adding it. Never add an adapter merely because search results mention HTTP support.

## Release-truth rule

Verify capabilities against the **exact deployed application/MCP release** and its published image/package, not:

- `main` branch code;
- an open or unmerged pull request;
- an issue requesting the feature;
- a search snippet that conflates proposed and released behavior.

For each claimed transport, inspect the exact tag’s entrypoint/source or run the pinned package’s `--help`. A project may advertise an MCP server while shipping only stdio.

## Credentials and scope

- Create a dedicated credential for Hermes/MCP rather than reusing a mobile-app or general integration key.
- Prefer granular scopes derived from the MCP tool surface. Read-only verification should not require broad administrative access.
- Do not print the credential or place it in skills, memory, logs, shell history, or reports.
- Store secrets in Hermes’s supported environment/config boundary and ensure file permissions are restrictive.
- Avoid direct database credential insertion unless the application has no supported creation path and the exact hashing/key format has been independently verified and tested. Supported UI/API generation is preferred.

## Verification checklist

1. Application API health succeeds from the MCP process’s network vantage.
2. Credential validation succeeds without interactive browser auth.
3. MCP initialization succeeds.
4. `tools/list` returns the expected schemas and tool count.
5. A harmless read-only tool call returns live application data.
6. If remote HTTP is used, unauthenticated requests fail and authenticated requests pass.
7. If a reverse proxy is involved, the MCP path does not fall through to the human UI’s Authelia/OIDC redirect.
8. Re-test after MCP reload/gateway restart so the long-lived Hermes process is using the new registration.

## Karakeep example (dated 2026-08)

Karakeep `0.33.1` ships an official MCP package/image whose released entrypoint uses stdio. Search results also surfaced HTTP-related development work, but exact-tag inspection showed it was not part of that release. For Hermes-only access, use the official stdio package directly against the Karakeep API. Do not deploy a transport gateway unless a shared remote `/mcp` endpoint is explicitly required.
