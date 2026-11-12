-- Liner Notes look: Wayline's structure as a handwritten zine. No chip blocks: labels are Monaspace Radon's
-- handwritten italics on paper (or chalk on slate for dark packs), the focused workspace gets a scribbled
-- underline, a meeting becomes a sticky note and the crew an ink stamp. Backdrop: shaders/paper.metal.
local look = table.clone(require("./wayline-base"))
look.personality = "liner"

local HAND = "Monaspace Radon"
local STICKY_INK = "#1c1917" -- dark ink reads on any pack's yellow note

local function scale(ctx) return ctx.data.bar.style.height / 40 end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

-- A wavy hand-drawn underline (viewBox 40x6), stretched to the label's width.
local SCRIBBLE = "M1 4 Q5 0.5 10 3.2 T20 3 T30 3.4 T39 2.6"

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local ink = if fill == "accent" or fill == "elevatedSurface" then "foreground" else fill
    local row = { gap = 5 * s, pad = 4 * s, h = 28 * s, hoverOpacity = 0.75, recolor(glyph, ink) }
    if label then
        row[#row + 1] = ui.text{ text = label, font = HAND, size = 14 * s, color = ink }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    pill.fill, pill.border, pill.radius = nil, nil, 0
    pill.h = 28 * scale(ctx)
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    local color = if focused then "foreground" elseif #workspace.windows > 0 then "secondaryForeground" else "mutedForeground"
    local width = 22 * m.scale
    local mark = { w = width, h = 26 * m.scale,
        ui.text{ text = string.lower(workspace.name), font = HAND, size = 16 * m.scale, color = color } }
    if focused then
        mark[#mark + 1] = ui.path{ d = SCRIBBLE, viewBox = { 0, 0, 40, 6 }, w = width, h = 5 * m.scale, align = "bottom", fill = "#00000000",
            border = "red", borderWidth = 1.6, pulse = { key = workspace.id, duration = 0.4, scale = { -0.6, 0.1, 0 } } }
    end
    return ui.stack(mark)
end

look.workspaceMetrics = function(_, style, m)
    return { item = 32 * m.scale, focusCue = false } -- the scribble is the focus cue, not a box
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius = nil, nil, 0
    pill.gap = 2 * m.scale
    pill.hover = "foreground/0.06"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = { h = 28 * s, gap = 6 * s, pad = 4 * s }
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 18 * s, h = 18 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = "— " .. m.title, font = HAND, size = 14 * s, color = "secondaryForeground",
            maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

-- The clock is handwritten; an upcoming meeting (the Fantastical widget puts "Title · 12m" in the date
-- slot) becomes a yellow sticky note slapped on at an angle.
look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = { h = 28 * s, gap = 8 * s, pad = 4 * s, hoverOpacity = 0.8 }
    if m.showDate and string.find(m.date, " · ", 1, true) then
        row[#row + 1] = ui.row{ pad = 6 * s, h = 22 * s, fill = "yellow", rotate = -2, shadow = "#00000040", shadowRadius = 2,
            ui.text{ text = m.date, font = HAND, size = 13 * s, color = STICKY_INK } }
    elseif m.showDate then
        row[#row + 1] = ui.text{ text = m.date, font = HAND, size = 13 * s, color = "secondaryForeground" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = HAND, size = 15 * s, color = "foreground" }
    return ui.row(row)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 15 * scale(ctx), color = "foreground" }, "accent")
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
