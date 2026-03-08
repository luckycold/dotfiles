---
name: research-mcps
description: Use mcporter-backed research services for docs lookup, code search, and web search.
compatibility: opencode
---

## When to use me

- Use this for library documentation, GitHub code examples, or broader web research.

## Server map

- `context7`: official and structured library docs
- `gh_grep`: real-world GitHub code search
- `kagi-ken`: web search and summarization

## Workflow

- Start with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list context7`, `mcporter --config "$HOME/.config/mcporter/mcporter.json" list gh_grep`, or `mcporter --config "$HOME/.config/mcporter/mcporter.json" list kagi-ken`.
- Prefer `context7` first for API and framework docs.
- Use `gh_grep` when you need real code patterns from public repositories.
- Use `kagi-ken` for web results, summarization, or broader background research.
- Before calling a tool, inspect the exact signature with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server> --all-parameters`.

## Practical guidance

- For unfamiliar libraries, combine `context7` first and `gh_grep` second.
- For comparison or discovery work, use `kagi-ken` after targeted docs/code lookup.
- Keep searches concrete and code-shaped when using `gh_grep`.
