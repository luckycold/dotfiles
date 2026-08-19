-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Preferred 170Hz on the AOC over the Thunderbolt dock exceeds link bandwidth
-- and Hyprland drops the panel, so pin 2560x1440@120.
hl.env("GDK_SCALE", "2")

-- Fallback first so it cannot override named outputs.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 2 })

hl.monitor({
  output = "desc:AOC Q27G3XMN 1APRBUA000024",
  mode = "2560x1440@120",
  position = "0x0",
  scale = 1,
})
hl.monitor({
  output = "desc:Dell Inc. DELL S2725QS F889T84",
  mode = "preferred",
  position = "auto-left",
  scale = 1.5,
})
hl.monitor({
  output = "desc:Dell Inc. DELL S2725QS J84BT84",
  mode = "preferred",
  position = "auto-left",
  scale = 1.5,
})
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "auto-right",
  scale = 2,
})

hl.workspace_rule({
  workspace = "1",
  monitor = "desc:Dell Inc. DELL S2725QS J84BT84",
  default = true,
})
hl.workspace_rule({
  workspace = "2",
  monitor = "desc:Dell Inc. DELL S2725QS F889T84",
  default = true,
})
hl.workspace_rule({
  workspace = "3",
  monitor = "desc:BOE NE135A1M-NY1",
  default = true,
})
