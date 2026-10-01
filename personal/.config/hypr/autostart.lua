-- Extra autostart processes.
o.launch_on_start("brave-origin")
o.launch_on_start("beeper")
o.launch_on_start("steam-launch")

-- Workspace and scrolling_width are applied only when a window opens:
-- these rules survive monitor-triggered reloads but still allow manual moves.
-- Match Teams separately because it shares Brave's browser process.
o.window("^brave-origin$", { workspace = "2 silent", no_initial_focus = true })
o.window("^brave-teams\\.cloud\\.microsoft__.*$", {
  workspace = "3 silent",
  no_initial_focus = true,
  scrolling_width = 2 / 3,
})
o.window("^Beeper$", { workspace = "3 silent", no_initial_focus = true, scrolling_width = 1 / 3 })
o.window("^steam$", {
  workspace = "9 silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})

require("hypr.steam")
