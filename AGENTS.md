# Repository Guidelines (Trimmed)

## Deployment model
- This repo is managed with GNU Stow profiles.
- Typical setup is `common` plus exactly one persona profile (`personal`, `work`, or `steamos`).
- Use dry runs before changes: `stow -n -t ~ common`.
- `root/` is for system-level files (target `/`), not `$HOME`.
- Luke-authored portable agent skills are tracked under `common/.agents/skills` and published in `luckycold/agent-skills`; `update-agent-skills` refreshes installed copies through `skills.sh`.

## Secret templates
- Secret-backed configs use `*.template.*` filenames (for example `foo.template.json` -> `foo.json`).
- Secrets that show the template {{pass://...}} refer to proton pass's cli `pass-cli` not the `pass` command.
- After editing template files or switching profiles, refresh generated outputs with:
  - `init-env-secrets --all` (non-interactive), or
  - `init-env-secrets -r` (interactive retry/selection).

## Validation
- There is no automated test suite in this repo.
- Validate changes with Stow dry runs and basic runtime checks:
  - `stow -n ...` for link simulation
  - reload affected shell/config session as needed.

## Bash execution
- Some repo workflows rely on shell functions defined by Luke's dotfiles, such as `init-env-secrets`.
- Non-interactive tool shells will not have those functions loaded by default.
- When an agent needs to run one of these functions, explicitly load Luke's shell environment first in that command invocation, then run the function.
- Do not assume the function exists in the tool shell without loading the shell config.
- If loading the shell config still does not make the function available, report that clearly and do not present the step as completed.

## Personal skills
- `common/.agents/AGENTS.md` is Luke's canonical cross-agent working agreement and personal-skill index; Stow exposes it as `~/.agents/AGENTS.md` and tool-specific global instruction files resolve to it.
- Luke-authored personal Agent Skills live in `common/.agents/skills/` (SKILL.md directories) and are marked with `author: Luke`.
- Stow `common` to expose them at `~/.agents/skills/`, which Codex, Cursor, and OpenCode discover natively. Claude receives required compatibility links under `~/.claude/skills/`.
- Do not invent a parallel skills tree. Add or edit the canonical copy under `common/.agents/skills/`.
- After a personal skill produces a verified reusable correction or workflow, update its canonical package before the final response by following `personal-skill-maintenance`.
- Do not self-modify third-party or bundled skills. Do not record secrets, transient state, or inferred preferences.
- Report skill changes and leave them uncommitted unless Luke explicitly asks for a commit.
- These skills can describe homelab and personal workflows. Review for hostnames, IPs, emails, and similar identifiers before committing.
- Approved private operational values belong in the Proton Pass-backed `common/.agents/private-context.template.md`; `init-env-secrets` renders the ignored local file `~/.agents/private-context.md`. Keep tracked skills placeholder-only.

## Security
- Do not commit real secrets or host-specific credentials.
- Keep secrets in template placeholders and local-only overlays.

## Git commits and pushes
- When work on this repo is done, commit it and push to `origin` without asking.
- Prefer finishing the change over offering to do it later.
- There is no harm in committing and pushing as long as the change is not sensitive.
- Still do not commit secrets, credentials, or host-specific private data.
- Do not force-push, rewrite published history, or change remotes unless Luke asked for that.

## Working agreement
- This file is a shared agreement between Luke and coding agents.
- It can be updated as we discover better operating rules over time.
- If an agent updates this file after deeper/long-form discovery, it must explicitly notify Luke in the response.
