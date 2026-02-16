# Repository Guidelines

## Project Structure & Module Organization
Dotfiles are grouped into five GNU Stow packages:
- `common/` - Base shell configuration (`.bashrc`, `.bash_aliases`, modular `.bashrc.d/` scripts), Neovim at `.config/nvim/`, and configs for Ghostty, Hyprland, Mako, Aerospace, Karabiner, Cursor, OpenCode, Elephant, Solaar, and envman. Includes Flatpak overrides in `.local/share/flatpak/overrides/`. Also includes utility scripts in `Applications/` (fp-browse, k-notify, proton-login).
- `personal/` - Personal workstation overrides: Ghostty themes, Hyprland autostart, and Exercism shell completions in `.bashrc.d/`.
- `work/` - Work-specific configs: netbird login helper in `.bashrc.d/` and work Hyprland autostart.
- `mac/` - macOS-specific configs: iTerm2 preferences in `Library/Preferences/`.
- `root/` - System-level configs deployed to `/` (not `$HOME`): Brave browser policies at `etc/brave/policies/` and udev rules at `etc/udev/rules.d/`.

Packages `common/`, `personal/`, and `mac/` include `.stow-local-ignore` files so only intentional files are linked; edit inside the package before restowing.

## Build, Test, and Development Commands
Use GNU Stow to manage deployment. `stow -t ~ common` installs the base profile, while `stow -t ~ personal` or `stow -t ~ work` switches personas. Run dry runs with `stow -n -t ~ common`, and refresh symlinks after edits with `stow -R -t ~ common`. Keep package roots clean because Stow mirrors folder layout directly into your home directory.

Some configs are generated from secret templates discovered by
`init-env-secrets`. Templates must follow `*.template.*`, where
`template` is the second-to-last `.` segment in the filename
(for example `foo.template.jsonc` -> `foo.jsonc`). After updating
template-based configs or profile links, rerun secret injection with
`init-env-secrets -r` (interactive picker) or `init-env-secrets --all`.

## Coding Style & Naming Conventions
Shell files stay POSIX-friendly with two-space indents and lowercase function names; reserve uppercase for exported environment variables. Alias names mirror the command they wrap (see `common/.bash_aliases`). Lua modules in `common/.config/nvim` also use two-space indents, return tables, and keep camelCase for plugin keys to match upstream defaults. Match existing directory casing when adding new trees.

## Neovim Configuration Layout
`init.lua` orchestrates the build by requiring `lua/options.lua`, `lua/keymaps.lua`, and the Lazy bootstrap pair (`lua/lazy-bootstrap.lua`, `lua/lazy-plugins.lua`). Plugin specs live in `lua/lucky/plugins/` with one file per plugin, loaded via `lazy-plugins.lua`; group related entries and annotate non-obvious chains. Health checks sit in `lua/lucky/health.lua`, while runtime docs belong in `doc/`—generate tags with `:helptags doc` after edits. Lockfile updates happen in `lazy-lock.json` only after running `:Lazy sync`.

## Testing Guidelines
There is no automated test suite. Validate changes with `stow -n` dry runs, source modified shell files in a fresh terminal (`source ~/.bashrc`), and inspect resulting links with `ls -l ~/<file>`. For risky adjustments, test both personal and work personas to confirm parity.

## Commit & Pull Request Guidelines
Recent history favors short, imperative subjects such as “Restructure .bashrc”; follow that voice and wrap body text at 72 columns. Note which profile you touched and list the Stow commands you ran. Pull requests should link issues when relevant, describe manual follow-up steps, and include screenshots only for visual app changes under `Applications`.

## Security & Configuration Tips
Never commit API keys, SSH material, or host-specific secrets; stash them in local-only overlays covered by `.stow-local-ignore`. Before sharing configs, scrub hostnames, emails, and tokens, then rerun your Stow dry run to confirm nothing sensitive leaks.
