-- Omarchy's launcher already restarts the shell after a crash. Prevent a
-- crashed PAM child from relaunching itself as a second shell instance.
hl.env("QS_DISABLE_CRASH_HANDLER", "1")

-- Extra autostart processes.
local home = os.getenv("HOME") or ""

o.launch_on_start("omarchy-launch-webapp https://teams.cloud.microsoft")
o.launch_on_start("brave-origin")
o.launch_on_start(home .. "/AppImages/oneleet.appimage --password-store=gnome-libsecret")
o.launch_on_start("betterbird")
o.launch_on_start("beeper")
o.launch_on_start("steam-launch")

-- Workspace and scrolling_width are applied only when a window opens:
-- these rules survive monitor-triggered reloads but still allow manual moves.
-- Match Teams separately because it shares Brave's browser process.
o.window("^brave-origin$", { workspace = "2 silent", no_initial_focus = true })
o.window("^brave-teams\\.cloud\\.microsoft__.*$", {
  workspace = "3 silent",
  no_initial_focus = true,
  scrolling_width = 2 / 3 + 0.1,
})
o.window("^Beeper$", { workspace = "3 silent", no_initial_focus = true, scrolling_width = 1 / 3 })

-- Teams can finish restoring after Beeper. Move its whole column to the
-- beginning when it opens, preserving both column widths and current focus.
hl.on("window.open", function(window)
  if not window or not window.class:match("^brave%-teams%.cloud%.microsoft__")
    or not window.workspace or window.workspace.id ~= 3 then
    return
  end
  local layout = window.layout
  if not layout or layout.name ~= "scrolling" or not layout.column
    or layout.column.index <= 0 then
    return
  end

  local previous_window = hl.get_active_window()
  local previous_workspace = hl.get_active_workspace()
  local monitor_workspace = window.monitor.active_workspace
  hl.dispatch(hl.dsp.focus({ window = window }))
  for _ = 1, layout.column.index do
    hl.dispatch(hl.dsp.layout("swapcol l"))
  end
  hl.dispatch(hl.dsp.focus({ workspace = monitor_workspace }))
  if previous_window then
    hl.dispatch(hl.dsp.focus({ window = previous_window }))
  elseif previous_workspace then
    hl.dispatch(hl.dsp.focus({ workspace = previous_workspace }))
  end
end)

o.window("^steam$", {
  workspace = "9 silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})

require("hypr.steam")
