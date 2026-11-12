-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local battery = require("../lib/battery")

function render(ctx)
    local state = battery.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local behaviour = { onClick = ui.popout, help = state.percent }
    local button = look.batteryDetailsBar and look.batteryDetailsBar(ctx, state)
    if not button then
        local scale = look.scale(ctx)
        local props = table.clone(behaviour)
        if ctx.data.bar.style.vertical then
            props.gap = scale
            props.pad = 2 * scale
            props[#props + 1] = battery.cell(state, 17 * scale, 10 * scale)
            props[#props + 1] = look.text{ text = state.text, size = 10 * scale }
        elseif state.mode == "inside" then
            props[#props + 1] = battery.cell(state, 30 * scale, 15 * scale, state.text)
        else
            props[#props + 1] = battery.cell(state, 23 * scale, 12 * scale)
            if state.mode == "beside" then
                props[#props + 1] = look.text{ text = state.percent, size = 13 * scale, reserve = state.reserve }
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
    return battery.popout(ctx)
end
