-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local stats = require("../lib/stats")

local function meter(ctx, entry, variant: string)
    local color = if entry.hot then "warning" else "accent"
    local scale = look.scale(ctx)
    if variant == "gauge" then
        return stats.gauge(entry.value, 22 * scale, color,
            look.text{ text = tostring(math.round(entry.value)), size = 10 * scale, weight = "medium" })
    end
    local glyph = look.glyph{ name = entry.symbol, size = 14 * scale }
    if ctx.data.bar.style.vertical then
        return ui.column{ gap = scale, glyph, look.text{ text = tostring(entry.value), size = 10 * scale } }
    end
    local reading = look.text{ text = ctx.format.percent(entry.value / 100), size = 13 * scale,
        reserve = ctx.format.percent(1) }
    if variant == "graph" then
        return ui.row{ gap = 5 * scale, glyph, stats.sparkline(entry.history, 34 * scale, 16 * scale, color), reading }
    end
    return ui.row{ gap = 5 * scale, glyph, reading,
        ui.progress{ value = entry.value / 100, w = 24 * scale, h = 3 * scale, radius = 1.5 * scale,
            fill = "foreground/0.08", color = color, animate = "ease" } }
end

function render(ctx)
    local state = stats.state(ctx)
    local button = look.statsBar and look.statsBar(ctx, state)
    if not button then
        local props = { gap = (if ctx.data.bar.style.vertical then 6 else 12) * look.scale(ctx) }
        for _, entry in state.meters do
            props[#props + 1] = meter(ctx, entry, state.variant)
        end
        props.onClick = ui.popout
        button = look.bar(ctx, props)
    end
    button.onClick = ui.popout
    return button
end

function popout(ctx)
    return stats.popout(ctx)
end
