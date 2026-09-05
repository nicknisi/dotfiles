-- {{ name }} — rendered by bin/theme from themes/templates/hyprland.lua.tpl.
-- config/hypr/hyprland.lua dofile()s this; `hyprctl reload` re-reads it on switch.
local active = "rgba({{ accent_strip }}ff)"
local inactive = "rgba({{ muted_strip }}aa)"

hl.config({
  general = {
    col = { active_border = active, inactive_border = inactive },
  },
  group = {
    col = { border_active = active, border_inactive = inactive },
  },
})
