-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

local CELL = 28

function render(ctx)
    return ui.row{}
end

local function paint(row, item, kind)
    if look.hiddenMenuRow then
        look.hiddenMenuRow(row, item, kind)
    end
    return row
end

local function menuRow(item, width)
    if item.separator then
        return ui.box(paint({ w = width, h = 9, pad = 4,
            ui.box{ h = 1, grow = 1, fill = "border" } }, item, "separator"))
    end
    local color = if item.enabled then "foreground" else "secondaryForeground"
    local row = paint({ w = width, h = CELL, pad = 5, gap = 6, radius = look.radius(7),
        hover = if item.enabled then look.hover else nil,
        look.text{ text = item.mark, w = 14, size = 13, color = color },
        look.text{ text = item.title, grow = 1, maxWidth = width - 120, size = 13, color = color },
        look.text{ text = item.shortcut, maxWidth = 80, size = 12, color = "secondaryForeground" },
        if item.submenu then look.glyph{ name = "chevron.right", w = 10, h = 10, color = color }
            else ui.box{ w = 10, h = 10 } }, item, "item")
    row.key = item.id
    row.onClick = if item.enabled then "hidden-bar-menu " .. item.id else nil
    if not item.enabled then
        row.hover = nil
    end
    return ui.row(row)
end

function popout(ctx)
    local hidden = ctx.data.hiddenBar
    local page = hidden.menu
    local width = math.min(320, hidden.maxWidth > 0 and hidden.maxWidth or 320)
    local rows = { w = width, pad = 8, gap = 0, scroll = true }
    local height = 16
    if not page then
        rows[#rows + 1] = look.text(paint({
            text = omniwm.l10n("Unavailable"), size = 13, color = "secondaryForeground" }, nil, "unavailable"))
        height += CELL
    else
        if page.backID and page.backID ~= "" then
            local back = paint({ w = width - 16, h = CELL, pad = 5, gap = 6, radius = look.radius(7),
                hover = look.hover,
                look.glyph{ name = "chevron.left", w = 14, h = 12 },
                look.text{ text = omniwm.l10n("Back"), size = 13, grow = 1 } }, page, "back")
            back.onClick = "hidden-bar-menu " .. page.backID
            rows[#rows + 1] = ui.row(back)
            height += CELL
        end
        if page.title ~= "" then
            rows[#rows + 1] = ui.box(paint({ w = width - 16, h = CELL, pad = 5,
                look.text{ text = page.title, size = 12, color = "secondaryForeground", maxWidth = width - 26 } },
                page, "title"))
            height += CELL
        end
        for _, item in page.rows do
            rows[#rows + 1] = menuRow(item, width - 16)
            height += if item.separator then 9 else CELL
        end
        if #page.rows == 0 then
            rows[#rows + 1] = ui.box(paint({ h = CELL, pad = 5,
                look.text{ text = omniwm.l10n("No menu items available"), size = 13, color = "secondaryForeground" } },
                page, "empty"))
            height += CELL
        end
    end
    rows.h = math.min(height, hidden.maxHeight > 0 and hidden.maxHeight or height)
    return if look.hiddenMenuPanel then look.hiddenMenuPanel(ctx, rows) else look.panel(ctx, rows)
end
