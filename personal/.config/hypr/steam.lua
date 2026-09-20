-- Keep the Steam client UI on the scale of the monitor it currently occupies.
-- Steam only reads -forcedesktopscaling at start, so steam-launch --sync
-- restarts the client when that monitor scale changes.
--
-- Omarchy's 1100x700 box is a 1x-era size. Keep a large window; steam-launch
-- applies a 1.25 UI-scale bias so 2x is not tiny in that wider client.

o.window({ class = "steam", title = "^Steam$" }, {
  center = true,
  size = { "monitor_w * 0.9", "monitor_h * 0.86" },
})
o.window({ class = "steam", title = "^Friends List$" }, {
  size = { "monitor_w * 0.28", "monitor_h * 0.8" },
})

local sync_timer

local function is_steam(window)
  return window ~= nil and window.class == "steam"
end

local function request_sync(window)
  if window ~= nil and not is_steam(window) then
    return
  end
  if sync_timer ~= nil then
    sync_timer:cancel()
  end
  sync_timer = hl.timer(function()
    sync_timer = nil
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/steam-launch --sync")
  end, { timeout = 400, type = "oneshot" })
end

hl.on("window.open", request_sync)
hl.on("window.active", function(window)
  request_sync(window)
end)
hl.on("window.move_to_workspace", function(window)
  request_sync(window)
end)
hl.on("workspace.move_to_monitor", function()
  request_sync()
end)
hl.on("monitor.layout_changed", function()
  request_sync()
end)
hl.on("hyprland.start", function()
  request_sync()
end)
