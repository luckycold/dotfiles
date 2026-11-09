# Omarchy stable baseline

This repository follows Omarchy stable. It does not keep an edge or RC testbed log, and it does not install a second updater, timer, or channel switcher.

## Supported update

Omarchy documents this in `manual/30-updates.md` on tag `v4.5.0` (released 2026-11-05):

https://github.com/omacom/omarchy/blob/v4.5.0/manual/30-updates.md

Release notes: https://github.com/omacom/omarchy/releases/tag/v4.5.0

On a machine that should stay on the supported path:

1. Take a disk snapshot before the channel change. `omarchy-update` also takes its own pre-update snapshot. Rollback is booting that snapshot from the Limine menu. `omarchy reinstall` resets user configuration and is not the rollback.
2. Switch channel once, from a terminal: `omarchy-channel-set stable`. That is the terminal form of Update > Channel > Stable. On a server, do not open the Omarchy menu or start a GUI app to do this.
3. That command refreshes pacman for the stable channel, installs the stable packages `omarchy` and `omarchy-settings` (replacing `omarchy-dev` and `omarchy-settings-dev` when the previous channel used them), then runs `omarchy-update -y` once. Stop there. Do not run `omarchy-update` again, and do not run `pacman -Syu` or `yay -Syu`. A direct pacman upgrade skips Omarchy's snapshot and migrations. If the command stops partway, its own error tells you to rerun `omarchy-channel-set stable`.
4. Leave `t3code.service` as the server integration. Do not add a T3 Code GUI autostart. The existing capture binding in `bindings.lua` stays.
5. Leave the mcporter template and Proton Pass placeholders as they are. Do not copy server-only display settings into the shared `monitors.lua`. The primary laptop is not updated by this document.

## Release dedup

A public channel listing at https://omarchylinux.org/releases/ on 2026-11-09 showed stable, RC, and edge all publishing Omarchy package `4.5.0-3`, with the edge Arch mirror about an hour behind upstream and the stable and RC mirrors hundreds of hours behind. Confirm that on the machine after the pacman refresh (`pacman -Si omarchy` and `omarchy-channel-current`). Do not treat the listing as a reason to pull edge. Tag `v4.5.0` itself installs `omarchy` and `omarchy-settings` on stable, and `omarchy-dev` / `omarchy-settings-dev` on edge.

One channel and one update is the whole switch. `omarchy-channel-set stable` already runs the update. A later edge pull, or a manual full upgrade, duplicates that and can move Hyprland off the build the packaged `cua-hyprland-plugin` was built for.

The channel command does not remove every package that only the previous channel published. Upstream describes that gap in https://github.com/omacom/omarchy/issues/14304. After the switch, list foreign packages with `pacman -Qm`. Remove only leftovers that are not part of the stable install. Keep the packaged `cua-hyprland-plugin` whose dependency matches the Hyprland version stable ships. Do not pin, hold, or rebuild Hyprland 0.57.

Migrations run inside that single update and are recorded by Omarchy. Do not replay them by hand.

- `migrations/1793477875.sh` in tag `v4.5.0` appends F9 and Super+Ctrl+X dictation binds to `~/.config/hypr/bindings.lua` when a dictation backend is selected and those exact keys are absent. This config binds Ctrl+F9, not F9, so the append can still happen and will write through the Stow symlink. Review `git status` afterward. Do not commit an appended block unless those legacy keys are wanted.
- Migration `1793467369`, the `monitors.lua` comment rewrite, is not in tag `v4.5.0`. This repo leaves the shared monitor comments unchanged. Server display settings stay off the primary laptop's monitor file.

## Keys stable 4.5 also binds

These defaults are in tag `v4.5.0` (`default/hypr/bindings/tiling.lua`, `utilities.lua`, and `input-method.lua`):

- Super+Alt+L cycles the workspace layout backward.
- Super+Shift+T opens Activity (btop).
- Super+Shift+I switches input language backward.

This config binds the same three keys. Each local bind unbinds the Omarchy bind first, so only one action runs. No other 4.5 behavior is patched here.
