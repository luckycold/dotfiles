# Repository Guidelines

## Project Structure & Module Organization
Dotfiles are grouped into GNU Stow packages. `common` covers shell defaults (`common/.bashrc`, `common/.bash_aliases`) and the Neovim tree at `common/.config/nvim`. `personal/Applications` holds workstation overrides, while `work` stays empty until you add client-specific configs. Each package includes a `.stow-local-ignore` so only intentional files are linked into `$HOME`; edit inside the package before restowing.

## Build, Test, and Development Commands
Use GNU Stow to manage deployment. `stow -t ~ common` installs the base profile, while `stow -t ~ personal` or `stow -t ~ work` switches personas. Run dry runs with `stow -n -t ~ common`, and refresh symlinks after edits with `stow -R -t ~ common`. Keep package roots clean because Stow mirrors folder layout directly into your home directory.

## Coding Style & Naming Conventions
Shell files stay POSIX-friendly with two-space indents and lowercase function names; reserve uppercase for exported environment variables. Alias names mirror the command they wrap (see `common/.bash_aliases`). Lua modules in `common/.config/nvim` also use two-space indents, return tables, and keep camelCase for plugin keys to match upstream defaults. Match existing directory casing when adding new trees and prefer hyphenated filenames such as `Applications/kitty.conf`.

## Neovim Configuration Layout
`init.lua` orchestrates the build by requiring `lua/options.lua`, `lua/keymaps.lua`, and the Lazy bootstrap pair (`lua/lazy-bootstrap.lua`, `lua/lazy-plugins.lua`). Plugin specs live in `lazy-plugins.lua`; group related entries and annotate non-obvious chains. Health checks sit in `lua/lucky/health.lua`, while runtime docs belong in `doc/`—generate tags with `:helptags doc` after edits. Lockfile updates happen in `lazy-lock.json` only after running `:Lazy sync`.

## Testing Guidelines
There is no automated test suite. Validate changes with `stow -n` dry runs, source modified shell files in a fresh terminal (`source ~/.bashrc`), and inspect resulting links with `ls -l ~/<file>`. For risky adjustments, test both personal and work personas to confirm parity.

## Commit & Pull Request Guidelines
Recent history favors short, imperative subjects such as “Restructure .bashrc”; follow that voice and wrap body text at 72 columns. Note which profile you touched and list the Stow commands you ran. Pull requests should link issues when relevant, describe manual follow-up steps, and include screenshots only for visual app changes under `Applications`.

## Security & Configuration Tips
Never commit API keys, SSH material, or host-specific secrets; stash them in local-only overlays covered by `.stow-local-ignore`. Before sharing configs, scrub hostnames, emails, and tokens, then rerun your Stow dry run to confirm nothing sensitive leaks.
