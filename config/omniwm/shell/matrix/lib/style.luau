-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local style = {}

style.hover = "accent/0.12"
style.width = 320

function style.batterySymbol(level: number, charging: boolean?): string
    if charging then
        return "battery.100percent.bolt"
    end
    if level > 85 then
        return "battery.100percent"
    end
    if level > 60 then
        return "battery.75percent"
    end
    if level > 35 then
        return "battery.50percent"
    end
    if level > 10 then
        return "battery.25percent"
    end
    return "battery.0percent"
end

function style.scale(ctx): number
    return ctx.data.bar.style.height / 40
end

function style.bar(ctx, props)
    local bar = ctx.data.bar.style
    local scale = style.scale(ctx)
    props.gap = props.gap or 5 * scale
    props.pad = props.pad or 4 * scale
    props.radius = 2 * scale
    if props.onClick or props.onRightClick then
        props.hover = props.hover or style.hover
    end
    if bar.backgrounds then
        props.fill = props.fill or "surface/0.86"
    end
    if bar.vertical then
        props.w = props.w or bar.height - 4
        return ui.column(props)
    end
    props.h = props.h or bar.height - 4
    return ui.row(props)
end

function style.panel(props)
    props.pad = props.pad or 14
    props.gap = props.gap or 12
    props.center = false
    return ui.stack{ w = props.w, h = props.h, radius = 2, material = "clear", attach = true,
        fill = "background", border = "border", borderWidth = 1, open = 0.2, close = 0.16,
        ui.shader{ source = "matrix-rain.metal", values = { 0.13, 0.7, 15, 0 }, fps = 30, radius = 2 },
        ui.column(props) }
end

function style.group(props)
    props.pad = props.pad or 12
    props.gap = props.gap or 8
    props.radius = 2
    props.fill = props.fill or "surface/0.92"
    props.border = "border/0.7"
    props.borderWidth = 1
    props.center = false
    return ui.column(props)
end

function style.heading(text: string, width: number?)
    return ui.row{ w = width, gap = 8,
        ui.text{ style = "caption", text = ">", size = 14, color = "accent" },
        ui.text{ style = "caption", text = text, size = 14, weight = "semibold", color = "accent" } }
end

function style.button(name: string, action, props)
    props = props or {}
    props.w = props.w or 28
    props.h = props.h or 28
    props.radius = props.radius or 2
    props.hover = style.hover
    props.onClick = action
    props[#props + 1] = ui.symbol{ name = name, size = 14, weight = "medium", color = props.color or "foreground" }
    return ui.stack(props)
end

return style
