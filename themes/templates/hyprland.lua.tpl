-- {{ name }} — rendered by bin/theme from themes/templates/hyprland.lua.tpl.
-- config/hypr/hyprland.lua dofile()s this; `hyprctl reload` re-reads it on switch.
local active = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }
local inactive = "rgba(595959aa)"

hl.config({
  general = {
    col = { active_border = active, inactive_border = inactive },
  },
  group = {
    col = { border_active = active, border_inactive = inactive },
  },
})
