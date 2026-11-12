-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

interval = 30

local look = require("../lib/look")
local worldClock = require("../lib/world-clock")

function render(ctx: Context)
    local state = worldClock.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local vertical = ctx.data.bar.style.vertical
    local behaviour = { onClick = ui.popout, help = if vertical then state.help else nil }
    local button = look.worldClockBar and look.worldClockBar(ctx, state)
    if not button then
        local scale = look.scale(ctx)
        local props = table.clone(behaviour)
        props[1] = look.glyph{ name = "globe", size = 14 * scale, weight = "medium" }
        if vertical then
            props.gap = scale
            props.pad = 2 * scale
            props[2] = look.text{ text = string.format("%02d", state.clocks[1].hour), size = 10 * scale }
        else
            for index = 1, state.shown do
                local clock = state.clocks[index]
                if index > 1 then
                    props[#props + 1] = ui.box{ w = 1, h = 12 * scale, fill = "border" }
                end
                props[#props + 1] = look.text{ text = clock.short, size = 11 * scale, color = "secondaryForeground" }
                props[#props + 1] = look.text{ text = clock.time, size = 13 * scale, reserve = "00:00 PM" }
            end
        end
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx: Context)
    return worldClock.popout(ctx)
end
