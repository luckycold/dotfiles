# Hermes update stash / harness-local-change audit

Use this when a Hermes update stashes or preserves local changes in the `hermes-agent` checkout.

## Classification pattern

1. Inspect current status and stashes:
   - `git status --short --branch`
   - `git stash list --date=local --format='%gd|%h|%cr|%gs'`
   - For each stash: `git stash show --stat <stash>` and `git stash show --name-status <stash>`.
2. Classify changes by blast radius:
   - **Keep / reapply only when narrow and concrete**: user-facing local integration implemented through supported extension seams, e.g. a plugin/backend directory plus the smallest explicit config hook needed for the local setup.
   - **Drop / restore**: edits to Hermes core harness behavior, model-provider connection logic, provider discovery semantics, broad default/fallback selection changes, or anything that makes this instance diverge from upstream in a way an update cannot own.
   - **Exception on Luke's HA add-on Hermes container** (see parent `infrastructure-hygiene` SKILL.md): **keep** narrow dashboard/add-on compatibility patches (`web/vite.config.ts` `base: "./"`, `web/src/lib/api.ts` import-meta fallback, `hermes_cli/dashboard_auth/prefix.py` prefix limit) when tagged or documented as HA add-on patches — do not drop them solely because they touch web sources.
3. Prefer supported extension seams over core patches:
   - For search backends, a plugin is acceptable; changing global fallback ordering or default provider resolution is not unless upstream explicitly supports it.
   - For Home Assistant add-on quirks, prefer add-on config/env/wrapper options when they exist; when the add-on still requires minimal web/dashboard patches, **commit them and cherry-pick after `hermes update`** rather than leaving a dirty tree that blocks updates.
4. After cleanup, verify:
   - `git diff --check`
   - Syntax/compile checks for touched files.
   - A focused smoke test of the retained integration.
   - Final `git status --short --branch`, with only intentional local integration files remaining.

## Concrete example from this environment

A Hermes update left local changes involving Kagi search and Home Assistant dashboard patches. The durable outcome on Luke's container (2026-07 follow-up) was:

- Keep the local Kagi search plugin files under `plugins/web/kagi/`.
- Keep only the minimal `tools/web_tools.py` explicit-backend availability hook needed for `web.search_backend: kagi`.
- Drop broader changes to `agent/web_search_registry.py` that inserted Kagi into global legacy fallback ordering.
- **Keep** HA add-on dashboard patches in `web/src/lib/api.ts` and `web/vite.config.ts` and `hermes_cli/dashboard_auth/prefix.py` — commit on a branch, run `hermes update`, then **`git cherry-pick`** the integration commit onto updated `main`.

This preserves Luke's preferred Kagi search path and HA dashboard base-path behavior without carrying hacky Hermes core/provider-routing drift.