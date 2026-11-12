-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local keyboardMode = require("../lib/keyboard-mode")
local look = require("../lib/look")

local TERRACOTTA = "#B66545FF"

local function iconColor(settings): string
    local color = settings.iconColor
    if type(color) == "string" and (#color == 7 or #color == 9) and string.match(color, "^#%x+$") then
        return color
    end
    return TERRACOTTA
end

function render(ctx: Context)
    local style = ctx.data.bar.style
    local locked = style.secureInput
    local item = style.height - 4
    local glyph = { size = look.px(ctx, "glyph") }
    local frame, size
    if look.omniwmButton then
        frame, size = look.omniwmButton(ctx, glyph, locked)
    end
    glyph.name = locked and "omniwm.lock" or "omniwm"
    glyph.color = iconColor(ctx.data.settings or {})
    glyph.w, glyph.h = glyph.size, glyph.size
    local behaviour = { onClick = "shell menu", onRightClick = "shell menu",
        help = locked and omniwm.l10n("Secure Input is on: Option shortcuts are paused")
            or omniwm.l10n("Window manager controls") }
    local button
    if frame then
        frame[1] = ui.symbol(glyph)
        button = ui.stack(frame)
    else
        local props = table.clone(behaviour)
        props.w, props.h = item, item
        props[1] = ui.symbol(glyph)
        button, size = look.bar(ctx, props), item
    end
    for key, value in behaviour do
        button[key] = value
    end
    return keyboardMode.wrap(style, button, size)
end
