---
name: work-mcps
description: Use mcporter-backed work system integrations like Linear, GitLab, ClickUp, Pylon, NetBox, and Gravwell.
compatibility: opencode
metadata:
  audience: work
  workflow: operations
---

## What I do

- Handle work systems for issues, merge requests, pipelines, support workflows, inventory lookups, and investigations.
- Route work-related MCP usage through `mcporter`.

## When to use me

Use this for issue tracking, merge requests, project updates, pipeline work, inventory lookup, or investigation workflows.
Use `research-mcps` instead when you want GitLab mainly as a code search tool.

## Server map

- `linear`: issues, comments, projects, docs, and status updates
- `gitlab`: issues, merge requests, pipelines, and labels; use `research-mcps` when you want GitLab as a general code search tool
- `clickup`: ClickUp MCP access when enabled
- `pylon`: Pylon MCP access when enabled
- `netbox`: infrastructure inventory and source-of-truth lookups
- `gravwell-prod`: work log and investigation workflows in Gravwell

## Default workflow

- Start with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server>` to confirm the available tools.
- Run `mcporter --config "$HOME/.config/mcporter/mcporter.json" auth <server>` for OAuth-backed services before the first call.
- Use `mcporter --config "$HOME/.config/mcporter/mcporter.json" call '<server>.<tool>(...)'` with the exact signature shown by `mcporter list`.
- For unstable or rarely used integrations like `clickup`, `pylon`, `netbox`, and `gravwell-prod`, list the server before every new workflow so you do not guess tool names.

## Working rules

- Prefer `linear`, `gitlab`, `netbox`, and `gravwell-prod` through `mcporter`, not through OpenCode-native MCP config.
- If a workflow depends on auth and fails, retry after `mcporter --config "$HOME/.config/mcporter/mcporter.json" auth <server>` before changing config.
