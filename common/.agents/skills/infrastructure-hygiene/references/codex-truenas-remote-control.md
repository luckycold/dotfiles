# Codex on an always-on TrueNAS/Linux host for ChatGPT Remote

Use this workflow when Luke wants an existing Codex CLI installation on an always-on NAS or Linux host to behave like a phone-accessible agent through the ChatGPT app.

## Architecture and boundaries

- Codex Remote is not a Hermes gateway clone. It can provide a ChatGPT-app interface to the host's Codex runtime, shell, files, skills, instructions, and Codex Memories.
- Skills are instructions/resources only. Copying them does **not** migrate Hermes sessions, Mem0 facts, MCP credentials, Home Assistant tools, cron jobs, Telegram routing, or authenticated connectors.
- OpenAI's documented mainstream flow uses the ChatGPT desktop app on macOS/Windows and starts the remote Codex app server over SSH. Recent Codex CLIs also expose an experimental managed app-server/Remote Control path that can work directly on Linux. Feature-detect it and verify a real pairing response; do not infer support from docs or version alone.
- Never expose app-server TCP/WebSocket transports directly to the LAN or internet. Keep the Unix-socket/SSH model. A root-owned Codex host has root blast radius even with sandboxing and approvals.

## Read-only reconnaissance

Run as the intended remote user and record only non-secret state:

```bash
command -v codex
codex --version
codex login status
codex doctor
codex features list
codex app-server daemon version
ps -eo pid,ppid,lstart,args | sed -n '/[c]odex.*app-server/p'
```

Confirm:

- `codex doctor` has healthy auth, databases, connectivity, sandbox, and no active rollouts before replacing an existing server.
- `codex` is on the login-shell `PATH`; ChatGPT SSH projects launch it through that shell.
- Existing config/plugins/MCP inventory is understood before writing.

## Skills: use the user skill location

OpenAI Codex scans user skills from `$HOME/.agents/skills`, not from the internal `$HOME/.codex/skills/.system` tree. Keep a transferred catalog in a dedicated subtree so it is auditable and independently replaceable:

```text
$HOME/.agents/skills/hermes/
```

Use `rsync -a` with narrow cache exclusions. Avoid a broad `--delete` until the dedicated destination has been confirmed. Preserve each skill directory with `SKILL.md` plus `references/`, `templates/`, `scripts/`, and assets.

Large Hermes catalogs may contain Hermes-only tool names or source-host paths. Add a compact global warning telling Codex to adapt procedures rather than blindly executing incompatible commands. Do not rewrite every imported skill during migration.

Verify discovery, not just file copy:

```bash
codex -C <workspace> debug prompt-input 'Verify setup only.'
```

Check the rendered model input contains the intended global instructions and representative skill names. Also compare source/destination `SKILL.md` counts or run an `rsync -ani --delete` dry run against the dedicated mirror.

## Global instructions and durable facts

Put short personal/host defaults in `$CODEX_HOME/AGENTS.md` (normally `~/.codex/AGENTS.md`). Include:

- Luke's direct, verify-live, finish-the-job operating style.
- TrueNAS middleware/UI-management preference and destructive-operation guardrails.
- Last-known topology explicitly labeled "verify before relying on it."
- Secret-handling and no-public-app-server rules.
- A pointer to `~/.agents/skills/hermes/` and the Hermes-tool compatibility caveat.

Keep `AGENTS.md` concise. Do not paste full Hermes memory or session history into it.

Codex Memories are separate and may be off by default. If available, back up `config.toml` and set:

```toml
[features]
memories = true
```

Verify with `codex features list`. This starts Codex's own memory system; it is not a Mem0 import.

## Convert an unmanaged app server to the managed daemon

A manually launched process such as:

```text
codex ... app-server --listen unix://
```

can block both `codex remote-control start` and `codex app-server daemon bootstrap` with:

```text
app server is running but is not managed by codex app-server daemon
```

Safe migration:

1. Confirm zero active rollouts and identify the exact app-server PID, parent, start time, and full command.
2. Obtain/confirm scope approval because the conversion interrupts any attached client.
3. Send `SIGTERM` only to the exact verified unmanaged app-server process; refuse if its command no longer matches.
4. Wait for that PID to exit.
5. Run:

```bash
codex app-server daemon bootstrap --remote-control
```

6. Verify the JSON reports `status: bootstrapped`, `remoteControlEnabled: true`, the expected managed binary/version, and a local control socket.
7. Verify live state:

```bash
codex app-server daemon version
ps -eo pid,ppid,args | sed -n '/[c]odex.*app-server/p'
```

Expected shape: a managed `app-server --remote-control --listen unix://` plus its update loop. Do not replace it with an ad-hoc systemd unit or public listener when the CLI bootstrap works.

## Pairing

After every other verification is complete, generate the short-lived code last:

```bash
codex remote-control pair --json
```

Give Luke only `manualPairingCode` and its human-readable expiry. Do not retain the long pairing token or save either code to memory/skills. In the ChatGPT mobile app, use **Remote → pair/add host → manual pairing**. If the code expires, generate a fresh one rather than troubleshooting the old code.

After pairing, use a read-only smoke prompt first: ask the remote chat to report `hostname`, `whoami`, `pwd`, confirm the intended workspace is visible, and name two expected skills. Then proceed to integrations.

## Phase-two integrations

Inventory before adding anything:

```bash
codex mcp list
codex plugin list
```

Add MCP servers/connectors individually and test each. Do not bulk-copy Hermes `.env`, OAuth files, auth databases, or secret-bearing config. Recreate scoped credentials using Codex/ChatGPT's supported mechanisms. Avoid cloning Hermes schedules until duplicate runs and delivery destinations have been reviewed.

## Verification checklist

- Codex version/auth/doctor healthy.
- Dedicated transferred skill tree present and prompt-visible.
- Global `AGENTS.md` prompt-visible.
- Memories feature shows enabled if selected.
- Managed daemon reports running with matching CLI/app-server versions.
- App server uses local Unix socket; no public listener.
- Manual pair API returns a real code and environment ID.
- Mobile read-only smoke confirms correct host, user, workspace, and skills.
