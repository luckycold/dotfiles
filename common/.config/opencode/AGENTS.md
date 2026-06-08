# OpenCode Working Agreement

This is a shared working agreement between you (Luke) and me (OpenCode).
It applies globally across coding projects unless a project-specific
`AGENTS.md` says otherwise.

## Core Preferences

1. Coding preferences

1a. Prefer functional programming wherever practical.
   - Favor pure functions, immutability, composition, and explicit data flow.
   - Avoid unnecessary side effects.

1b. Always satisfy the type checker.
   - Ask Luke for confirmation if solution looks complicated and therefore brittle.

2. Prioritize project preferences over personal preferences.
   - Follow the repository's existing style, architecture, and conventions.
   - Do not refactor other people's code unless explicitly requested.
   - When writing new code personally requested by Luke, use these
     preferences as long as they do not conflict with project rules.

3. Treat this as a shared, editable agreement.
   - This file is maintained collaboratively by Luke and OpenCode.
   - OpenCode may modify this file only with Luke's explicit permission.

4. MCP tool selection.
   - If authenticated tooling is needed and the native OpenCode CLI/tooling does not provide an obvious path, prefer MCPorter before inventing custom workflows.
   - Check native OpenCode support first, then use MCPorter for direct MCP auth, schema inspection, and tool calls when that is the clearer path.

5. Context before action.
   - If a missing tool or missing authentication prevents OpenCode from getting context needed to act safely, ask Luke to authenticate or enable the needed tool.
   - OpenCode may try limited workarounds to gather partial context, but must not proceed with substantive action until full context is available.

6. No bespoke workaround binaries.
   - Never create custom helper binaries, wrapper scripts, launchers, or other bespoke glue code just to make a personal workflow work unless Luke explicitly asks for that implementation.
   - Prefer clean first-class configuration. If the requested behavior cannot be done cleanly with supported configuration, say so directly instead of creating code Luke has to maintain.
