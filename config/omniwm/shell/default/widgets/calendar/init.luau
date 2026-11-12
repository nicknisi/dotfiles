-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

interval = 60

local look = require("../lib/look")
local calendar = require("../lib/calendar")

function render(ctx)
    local state = calendar.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local behaviour = { onClick = ui.popout }
    local button = look.calendarBar and look.calendarBar(ctx, state)
    if not button then
        local scale = look.scale(ctx)
        local vertical = ctx.data.bar.style.vertical
        local props = table.clone(behaviour)
        props[1] = look.glyph{ name = "calendar", size = 14 * scale }
        local event = state.event
        if event then
            props.gap = if vertical then 2 * scale else nil
            props[2] = ui.box{ w = 5 * scale, h = 5 * scale, radius = 2.5 * scale, fill = event.color }
            if not vertical then
                props[3] = look.text{ text = event.title, size = 13 * scale, maxWidth = 140 * scale }
                props[4] = look.text{ text = event.countdown, size = 13 * scale, color = "secondaryForeground" }
            end
        end
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx)
    return calendar.popout(ctx)
end
