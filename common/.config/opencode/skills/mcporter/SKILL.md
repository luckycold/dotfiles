---
name: mcporter
description: Use mcporter as the single entrypoint for external MCP servers instead of OpenCode-native MCP config.
compatibility: opencode
metadata:
  audience: general
  workflow: mcp
---

## What I do

- Route OpenCode MCP work through `mcporter`.
- Show you how to discover servers, inspect tools, authenticate, and call them.
- Keep MCP server definitions centralized in `common/.config/mcporter/mcporter.template.json`.

## When to use me

Use this when you need an external MCP-backed service.
Load this before assuming a service is exposed as a native OpenCode tool.

## Default workflow

- Use `bash` to call `mcporter --config "$HOME/.config/mcporter/mcporter.json" ...`.
- Start with `list` to see available servers.
- Run `list <server> --all-parameters` before guessing tool names or arguments.
- Run `auth <server>` if the server needs login.
- Call tools with the exact signature shown by `list <server>`.

## Server groups

- Research and code search: `kagi-ken`, `context7`, `gh_grep`, `gitlab`
- Work systems: `linear`, `gitlab`, `clickup`, `pylon`, `netbox`, `gravwell-prod`
- Infra and local systems: `home-assistant`

## Working rules

- Prefer `mcporter` over adding MCP entries back into OpenCode config.
- Edit `common/.config/mcporter/mcporter.template.json` first when you change MCP setup in this repo.
- Run `init-env-secrets --all` after changing secret-backed templates.
- If `mcporter` is unavailable in `PATH`, fall back to `npx mcporter --config "$HOME/.config/mcporter/mcporter.json" ...`.
