-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

function render(ctx: Context)
    return ui.row{}
end

local function glyph(item: HiddenBarItem)
    if item.image then
        return ui.image{ image = item.image, w = item.w, h = item.h }
    end
    return look.glyph{ name = "app.dashed", w = 16, h = 16, color = "secondaryForeground" }
end

local function lineRanges(widths: { number }, hidden: HiddenBar): { { number } }
    local ranges = {}
    if hidden.vertical then
        local capacity = hidden.maxHeight > 0 and math.max(1, math.floor(hidden.maxHeight / hidden.cell)) or #widths
        for first = 1, #widths, capacity do
            ranges[#ranges + 1] = { first, math.min(first + capacity - 1, #widths) }
        end
        return ranges
    end
    local first, used = 1, 0
    for index, width in ipairs(widths) do
        if index > first and hidden.maxWidth > 0 and used + width > hidden.maxWidth then
            ranges[#ranges + 1] = { first, index - 1 }
            first, used = index, 0
        end
        used += width
    end
    ranges[#ranges + 1] = { first, #widths }
    return ranges
end

function popout(ctx: Context)
    local hidden = ctx.data.hiddenBar
    local cell = hidden and hidden.cell or 20
    if not hidden or #hidden.items == 0 then
        return ui.stack{ w = 140, h = cell + 4,
            look.text{ text = omniwm.l10n("No hidden items"), style = "small", color = "secondaryForeground" } }
    end
    local vertical = hidden.vertical
    local widths = {}
    for index, item in ipairs(hidden.items) do
        widths[index] = math.max(20, math.ceil(item.w))
    end
    local lines = { gap = 2, center = not vertical }
    for _, range in ipairs(lineRanges(widths, hidden)) do
        local column = 0
        for index = range[1], range[2] do
            column = math.max(column, widths[index])
        end
        local line = { gap = 0, vertical and ui.box{ w = 1, h = 2 } or ui.box{ w = 2, h = 1 } }
        for index = range[1], range[2] do
            local item = hidden.items[index]
            local width = vertical and column or widths[index]
            line[#line + 1] = ui.stack{ key = item.id, w = width, h = cell, help = item.name,
                onClick = "hidden-bar activate " .. item.id,
                ui.box{ w = width - 4, h = cell - 4, radius = look.radius(6),
                    hover = look.hiddenBarHover or look.hover },
                glyph(item) }
        end
        line[#line + 1] = vertical and ui.box{ w = 1, h = 2 } or ui.box{ w = 2, h = 1 }
        lines[#lines + 1] = vertical and ui.column(line) or ui.row(line)
    end
    return ui.stack{ pad = 2, vertical and ui.row(lines) or ui.column(lines) }
end
