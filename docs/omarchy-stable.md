# Omarchy stable baseline

This repository follows Omarchy stable. It does not keep an edge or RC testbed log, and it does not install a timer, a second updater, or a channel switcher.

Host verification is pending. The checks in this pull request (`luac -p`, `stow -n`) did not migrate a machine and do not show that the server is on stable.

## One-time migration off RC or edge

Do this only when `omarchy-channel-current` prints `rc`, `edge`, or `dev`. Switching channels is not a routine update.

1. Take a disk snapshot first. Rollback of a bad transaction is that snapshot, or the pre-update snapshot `omarchy-update` takes, from the Limine menu. `omarchy reinstall` resets user configuration and is not the rollback.
2. From a terminal, once: `omarchy-channel-set stable`. That is the terminal form of Update > Channel > Stable. On a server, do not open the Omarchy menu or start a GUI app.
3. The command refreshes pacman for stable, installs `omarchy` and `omarchy-settings` (replacing `omarchy-dev` and `omarchy-settings-dev` when those are installed), then runs `omarchy-update -y` itself. Do not run `omarchy-update` again as part of this migration. Do not run `pacman -Syu` or `yay -Syu`. If it stops halfway, rerun `omarchy-channel-set stable`.
4. Read the versions in "Release state" below. When they already match, stop.
5. Packages that only the previous channel published can remain installed. Upstream describes that in https://github.com/omacom/omarchy/issues/14304. After this one migration, list them with `pacman -Qm` and remove only leftovers that are not part of the stable install. Keep the packaged `cua-hyprland-plugin`.

Leave `t3code.service` as the server integration. Do not add a T3 Code GUI autostart. The capture binding already in `bindings.lua` stays. Leave the mcporter template and Proton Pass placeholders as they are. Do not copy server-only display settings into the shared `monitors.lua`. The primary laptop is not updated by this document.

## Ongoing updates on stable

Do this only when `omarchy-channel-current` already prints `stable`.

The supported command in tag `v4.5.0` is `omarchy-update` (`bin/omarchy-update`; the same script's examples are `omarchy update` and `omarchy update -y`). Manual: https://github.com/omacom/omarchy/blob/v4.5.0/manual/30-updates.md

Run `omarchy-update` only when `omarchy-version` is older than the official stable package in "Release state". When the installed version is already that package, do nothing. Do not run `omarchy-channel-set` as part of a normal update. Do not run `pacman -Syu` or `yay -Syu`; a direct pacman upgrade skips Omarchy's snapshot and migrations.

## Release state

Checked Nov 8 CT.

Official release: git tag `v4.5.0`, published 2026-11-05. https://github.com/omacom/omarchy/releases/tag/v4.5.0

Official stable package database `https://pkgs.omarchy.org/stable/x86_64/omarchy.db` at that check:

- `omarchy` `4.5.0-3`, which conflicts with `omarchy-dev` and depends on `omarchy-settings=4.5.0`
- `omarchy-settings` `4.5.0-3`
- `cua-hyprland-plugin` `0.33.2-3`, which depends on `hyprland=0.56.2-4`

`omarchy-version` prints the pacman version of `omarchy`, or of `omarchy-dev` when that is what is installed.

Last tested in this repository, against tag `v4.5.0` source on Nov 8 CT: the three key unbinds below, and the two commands above. The server's channel and installed package versions have not been tested from here. Until that host check is done, do not treat `4.5.0-3` as already installed.

No duplicate action when nothing changed:

- Channel `stable`, `omarchy-version` prints `4.5.0-3`, `cua-hyprland-plugin` is `0.33.2-3`, and `hyprland` is `0.56.2-4`: do nothing.
- Channel is `rc`, `edge`, or `dev`: run the one-time migration once. It already updates. Then compare again. If the versions match, do not run `omarchy-update` a second time.
- Channel already `stable`, but `omarchy-version` is older than `4.5.0-3`: run `omarchy-update` once. Do not switch channels.
- A later official stable package newer than `4.5.0-3` is an ongoing `omarchy-update`, not another channel switch.

Do not pin or rebuild Hyprland 0.57. The stable plugin dependency is `hyprland=0.56.2-4`.

Migrations run inside the update Omarchy already invoked, and Omarchy records them. Do not replay them by hand.

- `migrations/1793477875.sh` in tag `v4.5.0` appends F9 and Super+Ctrl+X dictation binds to `~/.config/hypr/bindings.lua` when a dictation backend is selected and those exact keys are absent. This config binds Ctrl+F9, not F9, so the append can still happen and will write through the Stow symlink. Review `git status` afterward. Do not commit an appended block unless those legacy keys are wanted.
- Migration `1793467369`, the `monitors.lua` comment rewrite from the edge testbed, is not in tag `v4.5.0`. This repo does not carry that edit. Server display settings stay off the primary laptop's monitor file.

## Keys stable 4.5 also binds

Verified in tag `v4.5.0` (`default/hypr/bindings/tiling.lua`, `utilities.lua`, and `input-method.lua`):

- Super+Alt+L cycles the workspace layout backward.
- Super+Shift+T opens Activity (btop).
- Super+Shift+I switches input language backward.

This config binds the same three keys. Each local bind unbinds the Omarchy bind first, so only one action runs. These three unbinds are the stable key fixes. The edge testbed's `monitors.lua` comment edit and its rolling notes are not in this branch. No other 4.5 behavior is patched here.
