# OIDC Endpoint Discovery Example

During the Hermes MCP + Grok OAuth setup, the agent initially used `/api/oidc/authorize` based on common patterns. After the user provided the discovery document, it was observed that Authelia actually exposes:

- `authorization_endpoint`: `https://<private-auth-host>/api/oidc/authorization`

This mismatch caused repeated 404 errors. The correct path was discovered autonomously by querying the `.well-known/openid-configuration` endpoint rather than asking the user.

## Lesson
Always check the OIDC discovery document (`/.well-known/openid-configuration`) when authorization endpoints return 404, instead of guessing or asking for the exact path.
