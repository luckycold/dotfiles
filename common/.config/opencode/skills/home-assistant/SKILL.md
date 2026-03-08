---
name: home-assistant
description: Use the Home Assistant MCP through mcporter, including config and auth troubleshooting.
compatibility: opencode
---

## When to use me

- Use this for Home Assistant entity lookup, automation work, dashboards, or home state inspection.

## Workflow

- Start with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list home-assistant`.
- Inspect exact tool names and parameters with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list home-assistant --all-parameters`.
- Call tools with `mcporter --config "$HOME/.config/mcporter/mcporter.json" call 'home-assistant.<tool>(...)'`.

## Troubleshooting

- The bearer token lives in `common/.config/mcporter/mcporter.template.json` and is rendered into `~/.config/mcporter/mcporter.json`.
- If Home Assistant returns auth errors, update the template-backed secret and run `init-env-secrets --all`.
- Do not add Home Assistant back into OpenCode's native `mcp` config.
