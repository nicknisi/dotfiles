-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local weather = require("../lib/weather")

function render(ctx)
    local message = weather.accessMessage(ctx)
    if message then
        return look.bar(ctx, { onClick = ui.popout,
            look.text{ text = message, size = 11 * look.scale(ctx), maxWidth = 240 * look.scale(ctx) } })
    end
    local state = weather.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local button = look.weatherBar and look.weatherBar(ctx, state)
    if not button then
        local scale = look.scale(ctx)
        local props = { onClick = ui.popout, look.glyph{ name = state.symbol, size = look.px(ctx, "symbol") } }
        if ctx.data.bar.style.vertical then
            props.gap = scale
            props.pad = 2 * scale
            props[#props + 1] = look.text{ text = state.temp, size = 10 * scale }
        else
            props[#props + 1] = look.text{ text = state.temp, size = 13 * scale, reserve = "-00°" }
        end
        button = look.bar(ctx, props)
    end
    button.onClick = ui.popout
    return button
end

function popout(ctx)
    return weather.popout(ctx)
end
