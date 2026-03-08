---
name: work-mcps
description: Use mcporter-backed work system integrations like Linear, GitLab, ClickUp, and Pylon.
compatibility: opencode
---

## When to use me

- Use this for issue tracking, merge requests, project updates, pipeline work, or support workflows.

## Server map

- `linear`: issues, comments, projects, docs, and status updates
- `gitlab`: issues, merge requests, pipelines, labels, and code search
- `clickup`: ClickUp MCP access when enabled
- `pylon`: Pylon MCP access when enabled

## Workflow

- Start with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server>` to confirm the available tools.
- Run `mcporter --config "$HOME/.config/mcporter/mcporter.json" auth <server>` for OAuth-backed services before the first call.
- Use `mcporter --config "$HOME/.config/mcporter/mcporter.json" call '<server>.<tool>(...)'` with the exact signature shown by `mcporter list`.
- For unstable or rarely used integrations like `clickup` and `pylon`, list the server before every new workflow so you do not guess tool names.

## Working rules

- Prefer `linear` and `gitlab` through `mcporter`, not through OpenCode-native MCP config.
- If a workflow depends on auth and fails, retry after `mcporter --config "$HOME/.config/mcporter/mcporter.json" auth <server>` before changing config.
