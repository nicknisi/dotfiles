-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local inputSource = require("../lib/input-source")

function render(ctx)
    local state = inputSource.state(ctx)
    if not state then
        return ui.box{ w = 0, h = 0 }
    end
    local behaviour = { onClick = ui.popout, help = state.name }
    local button = look.inputSourceBar and look.inputSourceBar(ctx, state)
    if not button then
        local scale = look.scale(ctx)
        local props = table.clone(behaviour)
        props.pad = 2 * scale
        props[1] = ui.stack{ w = 23 * scale, h = 18 * scale, radius = 4 * scale, fill = "foreground/0.09",
            look.text{ text = state.short, size = 11 * scale, weight = "medium", maxWidth = 22 * scale } }
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx)
    return inputSource.popout(ctx)
end
