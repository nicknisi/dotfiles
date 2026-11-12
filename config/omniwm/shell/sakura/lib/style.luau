-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local style = {}

style.hover = "accent/0.09"
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
    props.radius = 12 * scale
    if props.onClick or props.onRightClick then
        props.hover = props.hover or style.hover
    end
    if bar.backgrounds then
        props.fill = props.fill or "surface/0.72"
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
    return ui.stack{ w = props.w, h = props.h, radius = 22, material = "clear",
        fill = "background", border = "border/0.8", borderWidth = 1, open = 0.22, close = 0.18,
        ui.shader{ source = "sakura-petals.metal", values = { 0.36, 0.8, 13, 0 }, fps = 30, radius = 22 },
        ui.column(props) }
end

function style.group(props)
    props.pad = props.pad or 12
    props.gap = props.gap or 8
    props.radius = 16
    props.fill = props.fill or "surface/0.72"
    props.border = "border/0.45"
    props.borderWidth = 1
    props.center = false
    return ui.column(props)
end

function style.heading(text: string, width: number?)
    return ui.row{ w = width, gap = 8,
        style.blossom(16),
        ui.text{ text = text, size = 14, weight = "semibold", color = "foreground" } }
end

function style.blossom(size: number)
    return ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, fill = "accent/0.85",
        d = "M12 11 C6 5 8 0 10 2 L12 4 L14 2 C16 0 18 5 12 11 Z "
            .. "M13 12 C17 4 22 5 21 8 L19 10 L22 11 C25 14 19 17 13 12 Z "
            .. "M13 13 C22 13 23 18 20 18 L17 18 L17 21 C15 25 11 21 13 13 Z "
            .. "M11 13 C13 21 9 25 7 21 L7 18 L4 18 C1 18 2 13 11 13 Z "
            .. "M11 12 C5 17 -1 14 2 11 L5 10 L3 8 C2 5 7 4 11 12 Z" }
end

function style.button(name: string, action, props)
    props = props or {}
    props.w = props.w or 28
    props.h = props.h or 28
    props.radius = props.radius or 10
    props.hover = style.hover
    props.onClick = action
    props[#props + 1] = ui.symbol{ name = name, size = 14, weight = "medium", color = props.color or "foreground" }
    return ui.stack(props)
end

return style
