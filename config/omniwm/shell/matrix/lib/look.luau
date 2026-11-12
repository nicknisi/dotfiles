-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local legacy = require("./style")

local function text(props)
    if props.color == nil and props.role == "secondary" then
        props.color = "secondaryForeground"
    end
    props.role = nil
    props.style = "caption"
    return ui.text(props)
end

return require("./skin")({
    base = 40,
    hover = legacy.hover,
    width = legacy.width,
    radius = function()
        return 2
    end,
    text = text,
    bar = legacy.bar,
    panel = function(_, props)
        return legacy.panel(props)
    end,
    group = legacy.group,
    heading = legacy.heading,
    button = legacy.button,
    primaryButton = { w = 36, h = 36, radius = 2, fill = "accent", color = "accentForeground" },
    controlCenterBar = function(ctx)
        local scale = legacy.scale(ctx)
        local item = { hover = legacy.hover,
            ui.symbol{ name = "slider.horizontal.3", size = 14 * scale, color = "accent" } }
        if not ctx.data.bar.style.vertical then
            item[#item + 1] = text{ text = "SYS", size = 12 * scale, color = "accent" }
        end
        return legacy.bar(ctx, item)
    end,
    controlCenterPanel = function(_, props)
        table.insert(props, 1, ui.row{ w = props.w - 28,
            text{ text = "matrix://", size = 11, color = "secondaryForeground", grow = 1 },
            legacy.button("xmark", ui.popout, { help = omniwm.l10n("Close") }) })
        return legacy.panel(props)
    end,
    activeWindowBar = function(ctx, m)
        local scale = legacy.scale(ctx)
        local item = { hover = legacy.hover }
        if m.showIcon then
            item[#item + 1] = ui.icon{ app = m.bundle, w = 18 * scale, h = 18 * scale, placeholder = "app.dashed" }
        end
        if m.showText then
            item[#item + 1] = text{ text = "~/" .. m.app, size = 11 * scale,
                color = "secondaryForeground", maxWidth = m.maxWidth }
        end
        return legacy.bar(ctx, item)
    end,
    clockBar = function(ctx, m)
        if ctx.data.bar.style.vertical then
            return nil
        end
        local scale = legacy.scale(ctx)
        local row = { gap = 8 * scale, hover = legacy.hover }
        if m.showIcon then
            row[#row + 1] = ui.symbol{ name = "calendar", size = 12 * scale }
        end
        if m.showDate then
            row[#row + 1] = text{ text = string.upper(m.date), size = 12 * scale, color = "secondaryForeground" }
            row[#row + 1] = text{ text = "//", size = 12 * scale, color = "accent" }
        end
        row[#row + 1] = text{ text = m.time, size = 12 * scale, weight = "medium", reserve = "00:00 PM" }
        return legacy.bar(ctx, row)
    end,
    workspaceMarker = function(ctx, workspace, style, m)
        if m.indicator ~= "numbers" or (m.compact and not style.labels) then
            return nil
        end
        local size = math.max(16, math.round(m.icon * 0.95))
        local pad = if utf8.len(workspace.name) <= 1 then size * 0.32 else 5
        return ui.row{ h = size + 8, radius = 2,
            fill = if workspace.focused then "accent" else "surface/0.65",
            ui.box{ w = pad, h = 1 },
            text{ text = workspace.name, size = 13 * style.height / 40, weight = "medium",
                color = if workspace.focused then "accentForeground" else "secondaryForeground",
                maxWidth = if m.vertical then m.item - 10 else nil },
            ui.box{ w = pad, h = 1 } }
    end,
})
