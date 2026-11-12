-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local presentation = require("./notification-presentation")

return presentation({
    scale = function(ctx) return ctx.data.bar.style.height / 40 end,
    hover = "foreground/0.07",
    buttonRadius = 7,
    icon = function(issue, size)
        return ui.symbol{ name = if issue then "bell.badge" else "bell", size = size,
            weight = "semibold", color = "accentForeground" }
    end,
    bar = function(ctx, props)
        local style = ctx.data.bar.style
        local size = style.height * 0.8
        local radius = math.floor(size * 0.24)
        local tile = { w = size, h = size,
            ui.box{ w = size, h = size, radius = radius, fill = "accent" } }
        if #props > 1 then
            tile[#tile + 1] = ui.box{ align = if style.vertical then "bottom" else "trailing",
                w = if style.vertical then size else radius, h = if style.vertical then radius else size, fill = "accent" }
        end
        tile[#tile + 1] = props[1]
        props[1] = ui.stack(tile)
        props.gap = 0
        props.radius = radius
        props.fill = "elevatedSurface"
        props.hoverOpacity = 0.9
        if #props > 1 then
            table.insert(props, 2, ui.box{ w = 6, h = 2 })
            props[#props + 1] = ui.box{ w = 6, h = 2 }
        end
        if style.vertical then
            props.w = size
            return ui.column(props)
        end
        props.h = size
        return ui.row(props)
    end,
    group = function(props)
        props.radius = 9
        props.fill = "elevatedSurface"
        return ui.column(props)
    end,
    panel = function(_, props)
        props.material = "clear"
        props.radius = 12
        props.fill = "surface"
        props.border = "border"
        props.borderWidth = 1
        return ui.column(props)
    end,
})
