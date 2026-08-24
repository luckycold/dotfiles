# Luke's Agent Working Agreement

This is the canonical cross-agent guidance for Luke's environments. Project-specific instructions take precedence when they conflict.

## Core preferences

- Prefer functional programming where practical: pure functions, immutability, composition, and explicit data flow.
- Satisfy the type checker. Ask Luke before choosing a complicated, brittle workaround.
- Follow each repository's existing style and architecture. Do not refactor unrelated code.
- Inspect current state before acting. Ask only when required information is external, sensitive, destructive, or depends on a material user choice.
- Prefer supported first-class configuration over custom wrappers, helper binaries, or bespoke glue unless Luke explicitly requests that implementation.
- When authenticated tooling is needed, prefer the agent's native tools and configured MCP integrations. If neither provides a clear supported path, ask Luke to enable or authenticate the appropriate integration instead of inventing custom glue.

## Dotfiles freshness

Personal skills and this agreement live in the Stow `common` package under `~/dotfiles` (or `$DOTFILES_DIR`). If the CLI, prompt, notification, or git status shows that checkout is behind remote — including "Dotfiles Update Available", "Run update-dotfiles", or `behind N` — sync **before any other work**. Stale skills are worse than a delayed answer.

1. Non-interactive shells do not load Luke's bash functions. In the same command, `source "${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash"`, then run `update-dotfiles --yes`.
2. That fast-forwards the clone, restows `common` plus any already-linked persona (`personal` / `work` / `steamos`), and refreshes secret templates with `init-env-secrets --all` when that function is available.
3. Re-read `~/.agents/AGENTS.md` and the skills this task needs.

Do not `git reset --hard`, stash unrelated work, or force-push. If a fast-forward fails, report the divergence and continue only with whatever skill copies are already on disk.

## Personal skills

Luke-authored personal skills are canonical under `~/.agents/skills/` and have `author: Luke` in `SKILL.md`. Load the relevant skill before acting:

- `infrastructure-hygiene` for Luke's Hermes, Home Assistant, TrueNAS, Proxmox, LAN, DNS, reverse-proxy, container, and infrastructure-maintenance work.
- `direct-action-preferences` for infrastructure, authentication, OAuth/OIDC, networking, and configuration tasks where read-only discovery should precede questions.
- `truenas-custom-apps` for TrueNAS SCALE custom application lifecycle and ix-apps structure.
- `proton-pass-cli` for Proton Pass CLI, scoped agent access, secret references, and headless/container authentication.
- `tasker-automation` for Android Tasker and Tasker WebUI workflows.
- `personal-skill-maintenance` when creating, correcting, consolidating, or extending Luke-authored skills.

Read a skill's directly linked references only as needed. Personal skills supplement project rules; they do not override a repository's explicit constraints.

## Private context

- Private hostnames, domains, network topology, privileged connection targets, and password-manager topology are rendered locally at `~/.agents/private-context.md` from Proton Pass. Read it only when a relevant task needs an exact private value.
- Skill documentation must use descriptive placeholders such as `<nas-ssh-target>` or `<private-app-domain>` and point to the private context when an exact value is required.
- Never quote, commit, or copy the rendered private context into logs, summaries, skills, or other tracked files.

## Self-learning

- After using a Luke-authored skill, update its canonical package before the final response when a verified reusable correction, user correction, or repeatable workflow would improve future runs.
- Create a new personal skill only for a non-trivial workflow likely to recur and only when no existing skill is a natural home.
- Make the smallest evidence-backed edit. Do not record secrets, transient state, or a durable preference inferred from one request.
- Never self-modify third-party, bundled, system, or project-owned skills.
- Report any skill change. Do not commit or push personal-skill changes unless Luke explicitly asks.

## Safety

- Never commit credentials, tokens, private keys, session material, or host-specific secrets.
- Before committing personal skills, review new hostnames, IP addresses, emails, device identifiers, and infrastructure topology with Luke.
