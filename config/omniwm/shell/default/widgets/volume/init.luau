-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local audio = require("../lib/audio")

function render(ctx)
    local m = audio.state(ctx)
    local behaviour = { onClick = ui.popout, onScroll = audio.scroll, help = omniwm.l10n("Volume") }
    local button = look.volumeBar and look.volumeBar(ctx, m)
    if not button then
        local scale = look.scale(ctx)
        local vertical = ctx.data.bar.style.vertical
        local props = table.clone(behaviour)
        props.gap = if vertical then 1 else 5 * scale
        props[1] = look.glyph{ name = m.symbol, size = 14 * scale }
        if m.volume then
            props[2] = look.text{ text = if vertical then tostring(m.volume) else m.percent,
                size = (if vertical then 10 else 13) * scale,
                reserve = if vertical then "100" else ctx.format.percent(1) }
        end
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx)
    local m = audio.model(ctx)
    return look.audioPanel and look.audioPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28, audio.content(ctx, nil, m) })
end
