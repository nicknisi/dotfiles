-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local legacy = require("./style")

return require("./skin")({
    base = 40,
    hover = legacy.hover,
    width = legacy.width,
    bar = legacy.bar,
    panel = function(_, props)
        return legacy.panel(props)
    end,
    group = legacy.group,
    heading = legacy.heading,
    button = legacy.button,
    primaryButton = { w = 36, h = 36, radius = 18, fill = "accent", color = "accentForeground" },
    workspaceMarker = function(_, workspace, style, m)
        if m.indicator ~= "numbers" or (m.compact and not style.labels) then
            return nil
        end
        local size = math.max(16, math.round(m.icon * 0.95))
        local pad = if utf8.len(workspace.name) <= 1 then size * 0.32 else 5
        return ui.row{ h = size + 8, radius = (size + 8) / 2,
            fill = if workspace.focused then "accent" else "accent/0.07",
            ui.box{ w = pad, h = 1 },
            ui.text{ text = workspace.name, size = 13 * style.height / 40, weight = "medium",
                color = if workspace.focused then "accentForeground" else "secondaryForeground",
                maxWidth = if m.vertical then m.item - 10 else nil },
            ui.box{ w = pad, h = 1 } }
    end,
})
