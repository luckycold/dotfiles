-- Omarchy's 1100x700 box is a 1x-era size. Keep a large Steam window so 2x
-- chrome is not packed into it. Scale itself comes from Steam's UI Scale
-- slider; the CEF scale restarter was withdrawn (see steam-launch).

o.window({ class = "steam", title = "^Steam$" }, {
  center = true,
  size = { "monitor_w * 0.9", "monitor_h * 0.86" },
})
o.window({ class = "steam", title = "^Friends List$" }, {
  size = { "monitor_w * 0.28", "monitor_h * 0.8" },
})
