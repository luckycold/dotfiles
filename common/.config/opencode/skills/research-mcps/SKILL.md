---
name: research-mcps
description: Use mcporter-backed research services for docs lookup, code search, and web search.
compatibility: opencode
metadata:
  audience: general
  workflow: research
---

## What I do

- Look up official library and framework docs.
- Search for real code patterns in GitHub or GitLab-hosted codebases.
- Broaden the search with web results and summaries when targeted sources are not enough.

## When to use me

Use this when you need library documentation, code examples, or general code search.
Use this for private or self-hosted GitLab repositories too.

## Server map

- `context7`: official and structured library docs
- `gh_grep`: real-world GitHub code search
- `gitlab`: general code search for GitLab-hosted repositories, plus related repo metadata when needed
- `kagi-ken`: web search and summarization

## Default workflow

- Prefer `context7` first for API and framework docs.
- Use `gh_grep` when you need real code patterns from public GitHub repositories.
- Use `gitlab` when you need code search or repository lookups in GitLab-hosted codebases.
- Use `kagi-ken` when you need broader web results or summarization.
- Inspect the exact signature with `mcporter --config "$HOME/.config/mcporter/mcporter.json" list <server> --all-parameters` before calling a tool.

## Search guidance

- For unfamiliar libraries, combine `context7` first and then `gh_grep` or `gitlab` depending on where the code lives.
- For comparison or discovery work, use `kagi-ken` after targeted docs/code lookup.
- Keep searches concrete and code-shaped when using `gh_grep` or `gitlab`.
