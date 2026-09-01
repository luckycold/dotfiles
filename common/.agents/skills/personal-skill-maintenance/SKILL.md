---
name: personal-skill-maintenance
description: Create and self-maintain Luke-authored personal Agent Skills after verified reusable workflows or corrections. Use when an agent learns a repeatable procedure, finds a skill is wrong or incomplete, or is asked to capture personal procedural knowledge.
author: Luke
---

# Personal Skill Maintenance

Treat Luke-authored personal skills as writable procedural memory shared across agents.

## Scope

- The canonical cross-agent working agreement and personal-skill index is `~/.agents/AGENTS.md`; tool-specific global instruction paths resolve to it or instruct the agent to load it.
- The canonical library is `~/.agents/skills/`.
- A skill is personal and writable only when its `SKILL.md` frontmatter contains `author: Luke`.
- Codex, Cursor, and OpenCode discover the canonical standard skill path directly. Claude's required `~/.claude/skills/` entries resolve to the same packages. Never create divergent copies.
- Do not self-modify third-party, bundled, system, or project-owned skills.

## Session start

At the start of each new run, refresh installed copies of this library with `update-agent-skills` (the skills.sh CLI) before other work. In non-interactive shells, source `${DOTFILES_DIR:-$HOME/dotfiles}/common/.bashrc.d/dotfiles_management.bash` in the same command first. Skip if this session already ran it. If Node.js or npm is missing, report that and continue with on-disk skills.

## When to learn

Update or create a personal skill when at least one is true:

- A non-trivial, repeatable multi-step workflow succeeded.
- Earlier steps failed and evidence established a durable working path.
- Luke corrected the approach or stated a durable preference.
- A loaded personal skill is materially wrong, incomplete, stale, or overly narrow.

Do not write a skill for a one-off result, transient status, speculation, or information the agent has not verified.

## Workflow

1. Inspect the loaded skill and its directly referenced support files.
2. Identify the smallest reusable lesson and the evidence supporting it.
3. Prefer a targeted edit:
   - Patch `SKILL.md` for a concise rule or procedure.
   - Add or update one directly linked reference for detailed commands or examples.
   - Create a new skill only when no existing Luke-authored skill is a natural home.
4. Apply the safety filter below.
5. Verify frontmatter, relative links, commands, and consistency with the observed system.
6. Before the final response, review the repository diff and report that the skill learned or corrected itself.

## Safety filter

- Never store passwords, tokens, private keys, session material, recovery data, or raw secret-manager identifiers.
- Do not add new personal identifiers, private hostnames, IP addresses, emails, device IDs, or infrastructure topology unless they are necessary to the reusable procedure and Luke has approved tracking that class of data.
- Generalize examples where exact values are not required.
- Do not convert a single request into a permanent preference.
- Preserve explicit hard rules unless Luke changes them.
- If sensitivity or durability is unclear, ask Luke instead of writing.
- Put approved private operational values in the Proton Pass-backed `~/.agents/private-context.md`, not in a skill. Keep only descriptive placeholders and the reusable procedure in version control.

## Creating a personal skill

- Use a lowercase hyphenated name and a directory containing `SKILL.md`.
- Include `name`, a specific trigger-oriented `description`, and `author: Luke`.
- Keep `SKILL.md` concise and place detailed material in directly linked `references/`, `scripts/`, `templates/`, or `assets/`.
- Include a `Self-maintenance` section pointing back to this skill.
- Do not commit or push the resulting changes unless Luke explicitly requests it.

## Curation

Ordinary Agent Skills have no portable usage counter, background review fork, archive ledger, or approval queue. Git provides review and rollback for this shared library.

- Never auto-delete or auto-archive a personal skill based only on apparent non-use.
- If two personal skills overlap substantially, propose or perform a conservative consolidation only when the current task establishes that it is safe.
- Preserve whole packages and repair relative links when consolidating.

## Self-maintenance

This skill may update itself when a verified change to agent discovery, skill portability, or the shared maintenance policy makes these instructions inaccurate. Apply the same evidence, safety, verification, and no-auto-commit rules above.
