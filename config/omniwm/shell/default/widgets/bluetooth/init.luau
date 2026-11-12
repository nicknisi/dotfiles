-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local bluetooth = require("../lib/bluetooth")

function render(ctx)
    local state = bluetooth.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local behaviour = { onClick = ui.popout, help = state.help }
    local button = look.bluetoothBar and look.bluetoothBar(ctx, state)
    if not button then
        local props = table.clone(behaviour)
        props[1] = bluetooth.glyph(state, 16 * look.scale(ctx))
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx)
    return bluetooth.popout(ctx)
end
