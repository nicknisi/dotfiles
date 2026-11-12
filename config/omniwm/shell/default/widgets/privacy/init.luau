-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

local INDICATORS = {
    { key = "microphone", symbol = "mic.fill", color = "orange", help = omniwm.l10n("Microphone in use") },
    { key = "camera", symbol = "video.fill", color = "green", help = omniwm.l10n("Camera in use") },
}

local function model(ctx)
    local privacy = ctx.data.privacy or {}
    local indicators, help = {}, {}
    for _, indicator in INDICATORS do
        if privacy[indicator.key] then
            indicators[#indicators + 1] = indicator
            help[#help + 1] = indicator.help
        end
    end
    if #indicators == 0 then
        return nil
    end
    return { indicators = indicators, icons = (ctx.data.settings or {}).icons == true, help = table.concat(help, ", ") }
end

function render(ctx)
    local m = model(ctx)
    if not m then
        return ui.box{ w = 0, h = 0 }
    end
    local button = look.privacyBar and look.privacyBar(ctx, m)
    if not button then
        local scale = look.scale(ctx)
        local props = { gap = 5 * scale }
        for _, indicator in m.indicators do
            props[#props + 1] = if m.icons
                then look.glyph{ name = indicator.symbol, size = 14 * scale, weight = "medium", color = indicator.color }
                else ui.box{ w = 6 * scale, h = 6 * scale, radius = 3 * scale, fill = indicator.color }
        end
        button = look.bar(ctx, props)
    end
    button.help = m.help
    return button
end
