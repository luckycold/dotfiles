-- Personal keybinding overrides. Omarchy defaults load first; unbind a default
-- before replacing it. See: omarchy menu keybindings --print

local home = os.getenv("HOME") or ""

-- Vim window navigation (from Omarchy 3 bindings.conf).
-- SUPER+H was unbound. These three replace:
--   SUPER+J  Toggle window split
--   SUPER+K  Keybindings (use SUPER+SPACE, then Keybindings)
--   SUPER+L  Toggle workspace layout (moved to SUPER+ALT+L below)
hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

o.bind("SUPER + H", "Move window focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + L", "Move window focus right", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + K", "Move window focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + J", "Move window focus down", hl.dsp.focus({ direction = "d" }))

o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

o.bind("SUPER + SHIFT + ALT + H", "Move workspace to left monitor", hl.dsp.workspace.move({ monitor = "l" }))
o.bind("SUPER + SHIFT + ALT + L", "Move workspace to right monitor", hl.dsp.workspace.move({ monitor = "r" }))

-- Layout toggle used to live on SUPER+L; vim focus owns that key now.
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Super+D was Walker in Omarchy 3. Omarchy 4's app launcher is the apps menu
-- (Super+Space is still the full Omarchy menu).
o.bind("SUPER + D", "Applications", "omarchy-menu toggle apps")

-- Personal app bindings that differ from Omarchy 4 defaults.

hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Music", { webapp = "https://app.music-assistant.io" })

hl.unbind("SUPER + SHIFT + G")
o.bind("SUPER + SHIFT + G", "Beeper", { launch = "beeper", focus = "beeper" })

hl.unbind("SUPER + SHIFT + SLASH")
o.bind("SUPER + SHIFT + SLASH", "Passwords", { launch = "proton-pass", focus = "proton-pass" })

o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })

o.bind("SUPER + SHIFT + I", "Install package", "omarchy-launch-floating-terminal-with-presentation omarchy-pkg-install")
o.bind("SUPER + ALT + I", "Install aur package",
  "omarchy-launch-floating-terminal-with-presentation omarchy-pkg-aur-install")
o.bind("SUPER + SHIFT + CTRL + I", "Install flatpak package",
  "omarchy-launch-floating-terminal-with-presentation " .. home .. "/Applications/fp-browse")
hl.unbind("SUPER + SHIFT + CTRL + R")
o.bind("SUPER + SHIFT + CTRL + R", "Remove flatpak package",
  "omarchy-launch-floating-terminal-with-presentation " .. home .. "/Applications/fp-browse --remove")
o.bind("SUPER + SHIFT + R", "Remove package", "omarchy-launch-floating-terminal-with-presentation omarchy-pkg-remove")
o.bind("SUPER + SHIFT + U", "Update Omarchy",
  "omarchy-launch-floating-terminal-with-presentation " .. home .. "/Applications/omarchy-update-with-flatpak")

if o.cmd_present("voxtype") then
  o.bind("F8", "Cancel dictation", "voxtype record cancel")
  o.bind("CTRL + F9", "Cancel dictation", "voxtype record cancel")
end
