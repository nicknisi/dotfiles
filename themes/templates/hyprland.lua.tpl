-- {{ name }} — rendered by bin/theme from themes/templates/hyprland.lua.tpl.
-- config/hypr/hyprland.lua dofile()s this; `hyprctl reload` re-reads it on switch.
--
-- The border is the pack's. A pack sets hyprland_active_border and
-- hyprland_inactive_border in colors.toml in Hyprland's own syntax, gradients
-- included ("rgba(..) rgba(..) 45deg"); one without them gets its accent and
-- muted. theme-color turns either into the literal hl.config takes, since the
-- Lua API wants a gradient as a table and rejects the space-separated string.
local active = {{ hyprland_active_border_lua }}
local inactive = {{ hyprland_inactive_border_lua }}

hl.config({
  general = {
    col = { active_border = active, inactive_border = inactive },
  },
  group = {
    col = { border_active = active, border_inactive = inactive },
  },
})
