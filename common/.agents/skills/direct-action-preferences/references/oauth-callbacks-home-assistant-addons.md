# OAuth callback handling in Home Assistant add-on / container setups

Context: Hermes may run inside a Home Assistant add-on container, where the user's browser cannot reach the container's loopback callback URL and an SSH server is not necessarily present inside the add-on.

Reusable pattern:

1. Do not assume SSH forwarding is available just because `ssh` client exists. Verify a server/listener first (`sshd`/Dropbear process, `ss -ltnp`, add-on docs) before suggesting `ssh -L` as the primary path.
2. For OAuth flows that support manual callback paste, prefer that path in HA add-on/container environments:
   - run the command from the add-on terminal or from the agent's tool session if the agent will keep the process alive;
   - open the printed authorization URL in the user's normal browser;
   - when the browser redirects to a failing `127.0.0.1`/loopback URL, copy the full address-bar URL;
   - paste it into the same waiting OAuth process.
3. Treat callback URLs as secrets: they can contain short-lived authorization `code` and `state` values. Prefer user-local paste into the terminal; if the agent must handle the URL, explicitly warn it is sensitive and redact values in summaries.
4. If a tunnel is still needed, adapt to the actual host/add-on networking model rather than giving generic SSH advice. Home Assistant add-ons often need ingress/add-on terminal/manual paste solutions instead of direct inbound SSH to the container.

Hermes-specific note: `hermes auth add google-gemini-cli` uses a PKCE OAuth flow. The callback URL/code must be provided to the same process that generated the auth URL because the verifier is process-local. Hermes' Google OAuth implementation accepts a full callback URL, a query string, or a bare code at its manual fallback prompt.