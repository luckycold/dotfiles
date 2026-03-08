---
name: mcporter
description: Use mcporter as the single entrypoint for external MCP servers instead of OpenCode-native MCP config.
compatibility: opencode
---

## When to use me

- Use this for any task that needs an external MCP-backed service.
- Load this before assuming a service is exposed as a native OpenCode tool.

## Core workflow

- Treat `common/.config/mcporter/mcporter.template.json` as the repo source of truth for MCP server definitions.
- Use the `bash` tool to call `mcporter` with the repo-managed config path.
- Start with discovery via `mcporter --config "$HOME/.config/mcporter/mcporter.json" list`.
- Inspect a specific server with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server>`.
- Expand full signatures with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server> --all-parameters`.
- If the server requires login, run `mcporter --config "$HOME/.config/mcporter/mcporter.json" auth <server>`.
- Call tools using the exact signature shown by `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server>`.
- Example: `mcporter --config "$HOME/.config/mcporter/mcporter.json" call '<server>.<tool>(arg: "value")'`.

## Configured servers

- Research: `kagi-ken`, `context7`, `gh_grep`
- Work systems: `linear`, `gitlab`, `clickup`, `pylon`
- Infra and local systems: `home-assistant`, `netbox`, `gravwell-prod`

## Working rules

- Prefer `mcporter` over adding MCP entries back into OpenCode config.
- When changing MCP setup in this dotfiles repo, edit `common/.config/mcporter/mcporter.template.json` first.
- After changing secret templates, refresh generated outputs with `init-env-secrets --all`.
- If `mcporter` is unavailable in `PATH`, fall back to `npx mcporter --config "$HOME/.config/mcporter/mcporter.json" ...`.
