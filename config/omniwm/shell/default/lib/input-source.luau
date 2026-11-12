-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local inputSource = { settings = "input-source settings", width = 292 }

function inputSource.state(ctx)
    local source = ctx.data.inputSource
    if not source then
        return nil
    end
    return { id = source.id, name = source.name, short = source.short }
end

function inputSource.model(ctx)
    local m = inputSource.state(ctx)
    if not m then
        return nil
    end
    m.sources = {}
    for _, entry in ctx.data.inputSource.sources do
        m.sources[#m.sources + 1] = { id = entry.id, name = entry.name, short = entry.short,
            selected = entry.id == m.id, command = "input-source select " .. entry.id }
    end
    return m
end

local function badge(text: string, selected: boolean)
    return ui.stack{ w = 30, h = 22, radius = look.radius(5), fill = "foreground/0.08",
        look.text{ text = text, size = 11, weight = "medium", color = if selected then "accent" else "secondaryForeground",
            maxWidth = 28 } }
end

function inputSource.content(ctx, width: number?, m)
    width = width or inputSource.width
    m = m or inputSource.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Unavailable"), width)
    end
    local rows = { gap = 3 }
    for _, entry in m.sources do
        rows[#rows + 1] = ui.row{ w = width - 24, gap = 10, pad = 3, radius = look.radius(7), hover = look.hover,
            onClick = entry.command,
            badge(entry.short, entry.selected),
            look.text{ text = entry.name, size = 13, grow = 1, maxWidth = width - 98,
                weight = if entry.selected then "medium" else nil },
            look.glyph{ name = "checkmark", w = 12, h = 12, color = "accent", opacity = if entry.selected then 1 else 0 } }
    end
    return ui.column{ w = width, gap = 12, center = false,
        look.heading(omniwm.l10n("Input Sources"), width),
        look.group(rows),
        ui.row{ w = width, gap = 10, pad = 6, radius = look.radius(7), hover = look.hover, onClick = inputSource.settings,
            look.glyph{ name = "keyboard", size = 14, color = "secondaryForeground" },
            look.text{ text = omniwm.l10n("Keyboard Settings…"), size = 13, grow = 1 },
            look.glyph{ name = "chevron.right", size = 10, color = "secondaryForeground" } } }
end

function inputSource.popout(ctx)
    local m = inputSource.model(ctx)
    return look.inputSourcePanel and look.inputSourcePanel(ctx, m)
        or look.panel(ctx, { w = inputSource.width + 28, inputSource.content(ctx, nil, m) })
end

return table.freeze(inputSource)
