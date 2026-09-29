-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    -- niri-like side-scrolling layout instead of dwindle.
    layout = "scrolling",
  },
})

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.config({
  scrolling = {
    -- Focus bindings need follow_focus; suppress hover scrolling with the
    -- maximum visibility threshold instead. Explicit navigation bypasses it.
    follow_focus = true,
    follow_min_visible = 1.0,
    -- Presets cycled by SUPER+CTRL+MINUS/EQUAL.
    explicit_column_widths = "0.25, 0.49, 0.75",
  },
})

-- First tiled window on a workspace takes most of the screen; later ones use column_width.
o.window({ workspace = "w[t0]" }, { scrolling_width = 0.75 })

hl.config({
  misc = {
    -- Variable Refresh Rate off.
    vrr = 0,
  },
  render = {
    -- Auto-switch to HDR mode when a fullscreen app uses HDR.
    cm_auto_hdr = 1,
  },
  xwayland = {
    -- Avoid nearest-neighbor filtering that can make scaled XWayland apps jagged.
    use_nearest_neighbor = false,
  },
  binds = {
    -- Vim focus (SUPER+H/J/K/L) should cross onto the next monitor.
    window_direction_monitor_fallback = true,
  },
})

-- Keep active windows fully opaque while preserving inactive dimming.
o.window({ tag = "default-opacity" }, { opacity = "1 override 0.9 override" })
o.window({ tag = "terminal" }, { opacity = "1 override 0.9 override" })

-- >>> omaland managed block >>>
-- Written by Omaland. Safe to hand-edit: Omaland re-reads this block
-- every time it opens, and only ever rewrites what's between the fences.
hl.config({
  decoration = {
    dim_inactive = true,
    dim_strength = 0.3,
    rounding = 14,

    glow = {
      enabled = false,
      range = 0,
    },
  },
})
-- <<< omaland managed block <<<
