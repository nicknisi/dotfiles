-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local battery = require("../lib/battery")

function render(ctx)
    local state = battery.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local button = look.batteryBar and look.batteryBar(ctx, state)
    if button then
        return button
    end
    local scale = look.scale(ctx)
    local glyph = look.glyph{ name = state.symbol, size = 14 * scale, color = if state.low then "error" else "foreground" }
    if ctx.data.bar.style.vertical then
        return look.bar(ctx, { gap = scale, pad = 2 * scale, glyph, look.text{ text = state.text, size = 10 * scale } })
    end
    return look.bar(ctx, { glyph, look.text{ text = state.percent, size = 13 * scale, reserve = state.reserve } })
end
