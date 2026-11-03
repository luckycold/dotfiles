# Omarchy edge testbed

Rolling notes for what current Omarchy edge would change on the stable laptop.
Later weekly passes append a new dated section here.

## 2026-11-02 pass

This pass's update was blocked because cua-hyprland-plugin pins hyprland 0.56.2 while edge shipped 0.57.0.

Stable is v4.0.6. Edge is quattro / 4.5.0-rc3+. Every laptop-impact item below is in 4.5.0-rc1 through rc3 and on edge, and is **not on stable**. Each item is marked **edge-only** or **on stable**.

1. **SUPER+ALT+L cancels itself.** **edge-only.** 4.5 binds it to "Cycle workspace layout back". This config's `bindings.lua` also binds "Toggle workspace layout" on that key. Without an unbind, both fire and cancel each other. Fixed in this PR with `hl.unbind` first.
2. **SUPER+SHIFT+T opens btop twice.** **edge-only.** 4.5 moved Activity there, and this config binds the same key to btop. Fixed in this PR with `hl.unbind` first.
3. **SUPER+SHIFT+I is double-bound.** **edge-only.** 4.5 `input-method.lua` binds "Switch input language back", which collides with this config's "Install package". Fixed in this PR with `hl.unbind` first.
4. **monitors.lua migration.** **edge-only** (migration 1793467369, added this week). It runs `omarchy-hyprland-monitor-config-upgrade`. The shared `monitors.lua` used to contain two comment lines Omarchy shipped, so the script would rewrite the file through the Stow symlink: new template on top, old content below, and a `monitors.lua.bak.<epoch>` left in the dotfiles repo. That leaves a dirty repo on the laptop. Fixed in this PR by rewording those two comments; the script then leaves the file alone.
5. **Monitor panel settings now win.** **edge-only.** The 4.5 monitor panel saves per-monitor scale, mode, and position under the Omarchy monitor settings state directory. Those override `monitors.lua` rules for the same monitor unless `omarchy_monitor_panel_settings = false`. Displays here are managed with hyprmoncfg plus `monitors.lua`. Setting that flag is still an open choice. Note only.
6. **Per-monitor workspaces.** **edge-only.** Each monitor gets a block of 10 (laptop panel 1–10, the next monitor 11–20, and so on). Super+1 through Super+0 are per monitor. Existing workspace rules pin workspaces 1, 2, and 3 to specific panels, autostart sends Brave to workspace 2 and Teams and Beeper to workspace 3, and a Lua hook checks `workspace.id ~= 3`. Under blocks those IDs all belong to one monitor's block, so the layout will likely change. Note only; needs a rethink when 4.5 lands.
7. **GDK_SCALE.** **edge-only.** 4.5 sets `GDK_SCALE` from the lowest monitor scale once a panel scale is chosen. This config's `monitors.lua` sets `GDK_SCALE=2` and loads after, so that value should still win. Note only.
8. **Dictation.** **edge-only** (added this week). If an Omarchy dictation backend is selected, Alt+Space toggles dictation and holding Right Alt is push-to-talk. Migration 1793477875 then appends F9 and SUPER+CTRL+X binds to `bindings.lua`, writing through the symlink into the repo. It only runs when a dictation backend is selected. Voxtype users who already use F9 should check. Note only.
9. **Terminal clipboard.** **edge-only.** In terminals, Super+C and Super+V now send Ctrl+Shift+C and Ctrl+Shift+V instead of Ctrl+Insert and Shift+Insert. The Ghostty config still binds shift+insert and control+insert, which keep working as direct keys. Super+C and Super+V now depend on Ghostty's default ctrl+shift+c and ctrl+shift+v. Note only.
10. **New default keys.** **edge-only.** Super+Q close, Super+A select all, Super+M minimize to dock, Super+Grave Quake console, Super+Ctrl+T themes, Super+Ctrl+W backgrounds, Super+Ctrl+N network (the nightlight shortcut was removed), Super+Shift+Q calculator, and notification keys reshuffled (Super+Comma acts on the newest card). None collide with this config except items 1–3. Note only.
11. **Limine.** **edge-only.** Limine waits 1 second and boots quietly. Set `timeout:` in the Limine config to keep the menu. Note only.
12. **New default apps.** **edge-only.** Hype, Monologue, Signed, Disktree, a Starship theme, and theme intros. New migrations install rtkit and omarchy-local-ai and set OpenCode 2's theme in the OpenCode CLI config only when no theme is set. This repo stows the OpenCode config directory; that CLI json file is not in the repo, so no conflict is expected. Note only.
13. **Hyprland 0.57.0 and omarchy-hyprland-titlebars 0.3.0.** **edge-only.** They are on edge now. The stable laptop has no CUA plugin, so the packaging pin in this pass does not apply there. Note only.
