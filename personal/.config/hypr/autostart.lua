-- Omarchy's launcher already restarts the shell after a crash. Prevent a
-- crashed PAM child from relaunching itself as a second shell instance.
hl.env("QS_DISABLE_CRASH_HANDLER", "1")

-- Extra autostart processes.
local home = os.getenv("HOME") or ""

-- Launch quietly on workspace 9. Exec rules only touch the windows this launch
-- opens, so later windows (e.g. Betterbird compose) still open where you are.
local function launch_on_start_quiet(command)
  hl.on("hyprland.start", function()
    hl.exec_cmd(o.launch(command), { workspace = "9 silent", no_initial_focus = true })
  end)
end

o.launch_on_start("omarchy-launch-webapp https://teams.cloud.microsoft")
o.launch_on_start("brave-origin")
launch_on_start_quiet(home .. "/AppImages/oneleet.appimage --password-store=gnome-libsecret")
launch_on_start_quiet("betterbird")
o.launch_on_start("beeper")
o.launch_on_start("t3code")

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

-- T3 Code opens hidden in the Omarchy scratchpad (SUPER + S shows it).
o.window("^(t3code|com\\.t3tools\\.T3Code)$", { workspace = "special:scratchpad silent", no_initial_focus = true })
