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

## Security
- Do not commit real secrets or host-specific credentials.
- Keep secrets in template placeholders and local-only overlays.
