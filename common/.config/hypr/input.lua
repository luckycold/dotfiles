-- Keep only personal input overrides here. Uncommented settings replace
-- Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    -- Caps is compose; Omarchy also maps both Shifts to Caps Lock (self-clearing).
    -- Repeat delay is slower than Omarchy's 250ms default.
    repeat_delay = 600,
  },
})

-- Three-finger swipe between workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
