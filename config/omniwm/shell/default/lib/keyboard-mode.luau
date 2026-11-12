-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local keyboardMode = {}

local function metrics(style: BarStyle, size: number)
    local mode = style.keyboardMode
    if mode == "normal" then
        return nil
    end
    local label, help
    if mode == "paused" then
        label, help = omniwm.l10n("Paused"), omniwm.l10n("OmniWM shortcuts are paused.")
    elseif mode == "prefix" then
        label, help = omniwm.l10n("Prefix"), omniwm.l10n("Prefix: the next key runs an OmniWM command. Escape cancels.")
    else
        label = omniwm.l10n("Window Mode")
        help = omniwm.l10n("Window mode: keys run OmniWM commands until you press Escape.")
    end
    return {
        tint = if mode == "paused" then "warning" else "success",
        symbol = if mode == "paused" then "pause.fill" else "keyboard",
        label = if style.vertical then nil else label,
        help = help,
        pad = math.floor(size * 0.25),
        glyph = math.floor(size * 0.55),
        gap = 4,
        font = { size = math.floor(size * 0.5), weight = "semibold" },
    }
end

function keyboardMode.width(ctx: Context, style: BarStyle, size: number): number
    local m = metrics(style, size)
    if m == nil then
        return 0
    end
    local width = 2 * m.pad + m.glyph
    if m.label then
        width += m.gap + ctx.format.measure(m.label, m.font)
    end
    return width
end

function keyboardMode.chip(style: BarStyle, size: number)
    local m = metrics(style, size)
    if m == nil then
        return nil
    end
    return ui.row{ h = size, pad = m.pad, gap = m.gap, center = true, radius = size / 2,
        fill = m.tint .. "/0.18", help = m.help,
        ui.symbol{ name = m.symbol, size = m.glyph, color = m.tint },
        if m.label then ui.text{ text = m.label, size = m.font.size, weight = m.font.weight, color = m.tint }
            else nil }
end

function keyboardMode.wrap(style: BarStyle, button: Element, size: number): Element
    local chip = keyboardMode.chip(style, size)
    if chip == nil then
        return button
    end
    return if style.vertical then ui.column{ gap = 4, center = true, button, chip }
        else ui.row{ gap = 4, center = true, button, chip }
end

return keyboardMode
