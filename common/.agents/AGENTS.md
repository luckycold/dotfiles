# Luke's Agent Working Agreement

This is the canonical cross-agent guidance for Luke's environments. Project-specific instructions take precedence when they conflict.

## Core preferences

- Inspect current state before acting. Ask only when required information is external, sensitive, destructive, or depends on a material user choice.
- Prefer supported first-class configuration over custom wrappers, helper binaries, or bespoke glue unless Luke explicitly requests that implementation.
- Before writing custom wrappers, helper binaries, systemd units, or other glue, ask Luke whether a simpler maintained package can be installed instead.
- When authenticated tooling is needed, prefer the agent's native tools and configured MCP integrations. If neither provides a clear supported path, ask Luke to enable or authenticate the appropriate integration instead of inventing custom glue.

## Git push and merge

- Do not push by default. Push only when Luke explicitly authorizes it for the current repository or task, or when this agreement or the active repository's instructions grant it.
- Push permission is narrowly scoped. Never carry it from one repository, task, or prior conversation into another. A request to inspect, edit, implement, test, or commit is not by itself permission to push.
- Standing grant for `luckycold/agent-skills` only: commit and push skill updates straight to `main`, without asking and without a pull request, as long as `python3 scripts/check-public-safety.py` (which includes the 200-line `SKILL.md` check) passes before each push. Report every changed skill and its pushed commit. Every other repository, including dotfiles, keeps its own rules.
- Never merge a pull request Luke is reviewing; he merges his own PRs. Never force-push or rewrite published history unless Luke explicitly authorizes it.

## Skill freshness

At the start of each new run — once per session, not every turn — refresh installed portable skills before other work.

Non-interactive shells do not load Luke's bash functions. In the same command:

```bash
source "${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash"
update-agent-skills
```

That runs the skills.sh (`skills`) CLI, `add luckycold/agent-skills --skill '*' --global --yes`, for Codex, Claude Code, Cursor, and OpenCode: real copies in `~/.agents/skills/<skill>` and `~/.claude/skills/<skill>` links to them. When nothing changed upstream it only checks the remote and prints one line. `update-dotfiles --yes` runs it too. If this session already ran it, skip. It needs Node.js 22.20+ and npm, or mise (it also looks in `~/.local/share/agent-tools/bin`); if neither is available it says so, and you continue with the on-disk skills. After a refresh that changed files, re-read `~/.agents/AGENTS.md` and the skills this task needs.

## MCP aggregation

- `~/.mcporter/mcporter.json` is the canonical MCP registry. Render it from `common/.mcporter/mcporter.template.json` with `init-env-secrets`.
- The mcporter CLI is the primary way to hook up MCP servers through config files: `mcporter config add|remove|list|get|doctor` (and `mcporter config login` for OAuth). Agent clients such as Codex, OpenCode, and Zed connect only to `~/.local/bin/mcporter-mcp`; do not add upstream MCP server definitions to their own configs.
- For a server every host should have, also add it to the mcporter template so the next render keeps it. Keep credentials as Proton Pass placeholders, never literal values.
- The default bridge set is `kagi-ken,context7,gh_grep,gitlab,mem0`. Override per host with `MCPORTER_SERVERS`. Set `"imports": []` in the registry so mcporter does not re-import the client configs it now fronts.

## Dotfiles freshness

This agreement is stowed from the `common` package under `~/dotfiles` (or `$DOTFILES_DIR`). Portable skills are **not** in the dotfiles tree; they are installed from `luckycold/agent-skills` into `~/.agents/skills` by `update-agent-skills`. If the CLI, prompt, notification, or git status shows that checkout is behind remote — including "Dotfiles Update Available", "Run update-dotfiles", or `behind N` — sync **before any other work**. Stale skills are worse than a delayed answer.

1. Non-interactive shells do not load Luke's bash functions. In the same command, `source "${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash"`, then run `update-dotfiles --yes`.
2. That fast-forwards the dotfiles checkout, restows `common` plus any already-linked persona (`personal` / `steamos` / `agent`), refreshes secret templates with `init-env-secrets --all` when allowed, and runs `update-agent-skills`.
3. Re-read `~/.agents/AGENTS.md` and the skills this task needs.

Do not `git reset --hard`, stash unrelated work, or force-push. If a fast-forward fails, report the divergence and continue only with whatever skill copies are already on disk.

## Personal skills

Luke-authored skills are installed in `~/.agents/skills/` from `luckycold/agent-skills` and have `author: Luke` in `SKILL.md`. Load the relevant skill before acting on Luke's infrastructure, authentication, automation, or agent-maintenance work. They supplement project rules; they do not override a repository's explicit constraints. Use `personal-skill-maintenance` when creating, correcting, consolidating, or extending them.

## Private context

- Private hostnames, domains, network topology, privileged connection targets, and password-manager topology are rendered locally at `~/.agents/private-context.md` from Proton Pass. Read it only when a relevant task needs an exact private value.
- Skill documentation must use descriptive placeholders such as `<nas-ssh-target>` or `<private-app-domain>` and point to the private context when an exact value is required.
- Never quote, commit, or copy the rendered private context into logs, summaries, skills, or other tracked files.

## Self-learning

- After using a Luke-authored skill, update it in `luckycold/agent-skills` before the final response when a verified reusable correction, user correction, or repeatable workflow would improve future runs. Pushing follows the standing grant above.
- Create a new personal skill only for a non-trivial workflow likely to recur and only when no existing skill is a natural home.
- Make the smallest evidence-backed edit. Do not record secrets, transient state, or a durable preference inferred from one request.
- Never self-modify third-party, bundled, system, or project-owned skills.
- Always name every created or updated skill and its commit in the final response.

## Safety and the public skills repository

`luckycold/agent-skills` is public. It holds portable procedures, not Luke's live environment values.

- Never commit credentials, tokens, private keys, session material, recovery data, secret-manager IDs, auth files, or rendered private context, in any repository.
- In `luckycold/agent-skills`, never commit private hostnames, private domains, RFC1918 addresses, emails, MAC or device IDs, account aliases, or detailed live topology. Use placeholders such as `<nas-ssh-target>`.
- Run `python3 scripts/check-public-safety.py` there before every commit. It includes `scripts/check_skill_size.py`, which fails any `skills/*/SKILL.md` over 200 lines and warns above 100; move detail into linked `references/`. Treat a failure as blocking; fix or generalize the content rather than weakening the check.
- Before committing new hostnames, IP addresses, emails, device identifiers, or infrastructure topology to any other repository, review them with Luke.
