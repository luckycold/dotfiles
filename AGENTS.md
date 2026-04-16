# Repository Guidelines (Trimmed)

## Deployment model
- This repo is managed with GNU Stow profiles.
- Typical setup is `common` plus exactly one persona profile (`personal` or `work`).
- Use dry runs before changes: `stow -n -t ~ common`.
- `root/` is for system-level files (target `/`), not `$HOME`.

## Secret templates
- Secret-backed configs use `*.template.*` filenames (for example `foo.template.json` -> `foo.json`).
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
- When OpenCode needs to run one of these functions, explicitly load Luke's shell environment first in that command invocation, then run the function.
- Do not assume the function exists in the tool shell without loading the shell config.
- If loading the shell config still does not make the function available, report that clearly and do not present the step as completed.

## Security
- Do not commit real secrets or host-specific credentials.
- Keep secrets in template placeholders and local-only overlays.

## Working agreement
- This file is a shared agreement between Luke and OpenCode.
- It can be updated as we discover better operating rules over time.
- If OpenCode updates this file after deeper/long-form discovery, OpenCode must explicitly notify Luke in the response.
