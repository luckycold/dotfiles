-- Extra autostart processes.
o.launch_on_start("brave-origin")
o.launch_on_start("beeper")
o.launch_on_start("steam-launch")

-- Chat apps always open on workspace 3. Brave restores the Teams web app
-- with its session, so match the web app's own class, not the browser.
o.window("^brave-teams\\.cloud\\.microsoft__.*$", { workspace = "3 silent" })
o.window("^Beeper$", { workspace = "3 silent" })

-- Boot-only placement. Exec rules follow child processes, so an exec rule on
-- Brave would override the Teams rule above, and steam-launch --sync can
-- restart Steam outside the exec'd process. Use class rules that are enabled
-- only while startup settles, so later windows open where they are launched.
-- They start disabled so a config reload does not re-arm them.
local boot_rules = {
  { rule = hl.window_rule({ match = { class = "^brave-origin$" }, workspace = "2 silent", enabled = false }), timeout = 45000 },
  { rule = hl.window_rule({ match = { class = "^steam$" }, workspace = "9 silent", enabled = false }), timeout = 180000 },
}

hl.on("hyprland.start", function()
  for _, boot in ipairs(boot_rules) do
    boot.rule:set_enabled(true)
    hl.timer(function()
      boot.rule:set_enabled(false)
    end, { timeout = boot.timeout, type = "oneshot" })
  end
end)

require("hypr.steam")
