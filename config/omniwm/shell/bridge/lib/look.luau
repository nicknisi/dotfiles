-- Bridge look: Wayline's structure as a Star Trek LCARS console, for a bar run by an agent named Riker.
-- Every widget is a rounded console segment with black condensed capitals (Antonio), the crew is the
-- "away team" and the clock shows a stardate. The backdrop (shaders/lcars.metal) draws the elbow.
local look = table.clone(require("./wayline-base"))
look.personality = "bridge"
look.ink = "#000000" -- widgets print in black on the console segments

local FONT = "Antonio"
local INK = "#000000"
local SEGMENT_HUE = { accent = "orange", elevatedSurface = "purple", warning = "red", success = "green" }

local function scale(ctx) return ctx.data.bar.style.height / 40 end

-- Everything on a segment is printed in black, like LCARS labels.
local function ink(element)
    if type(element) ~= "table" then return end
    if element.color ~= nil then element.color = INK end
    if element.d ~= nil and element.fill ~= nil then element.fill = INK end
    for _, child in ipairs(element) do ink(child) end
end

local function segment(props, hue: string, s: number)
    props.fill, props.radius, props.h = hue, 12 * s, 24 * s
    props.border, props.shadow = nil, nil
    props.hoverOpacity = 0.8
    for _, child in ipairs(props) do ink(child) end
    return props
end

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local row = segment({ gap = 6 * s, pad = 10 * s, glyph }, SEGMENT_HUE[fill] or fill, s)
    if label then
        row[#row + 1] = ui.text{ text = string.upper(label), font = FONT, size = 14 * s, weight = "bold", color = INK }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    segment(pill, if pill.border == "warning" then "red" else "purple", scale(ctx))
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local hue = if workspace.focused then "orange" elseif #workspace.windows > 0 then "blue" else "purple/0.55"
    return ui.stack{ w = 30 * m.scale, h = 24 * m.scale, radius = 12 * m.scale, fill = hue,
        ui.text{ text = workspace.name, font = FONT, size = 14 * m.scale, weight = "bold", color = INK } }
end

look.workspaceMetrics = function(_, style, m)
    return { item = 30 * m.scale, focusCue = false }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius, pill.gap = nil, nil, 12 * m.scale, 3 * m.scale
    pill.hover = "foreground/0.08"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = segment({ gap = 6 * s, pad = 10 * s }, "blue", s)
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 16 * s, h = 16 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = string.upper(m.title), font = FONT, size = 14 * s, weight = "bold",
            color = INK, maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

-- Stardate the way fans count it from today's date: (year - 1946) * 1000, plus the fraction of the year.
local function stardate(): string
    local t = os.date("*t")
    local fraction = ((t.yday - 1) + (t.hour + t.min / 60) / 24) / 365
    return string.format("%.1f", (t.year - 1946) * 1000 + fraction * 1000)
end

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = segment({ gap = 8 * s, pad = 12 * s }, "orange", s)
    local meeting = m.showDate and string.find(m.date, " · ", 1, true)
    row[#row + 1] = ui.text{ text = if meeting then string.upper(m.date) else "STARDATE " .. stardate(), font = FONT,
        size = 14 * s, weight = "bold", color = INK }
    row[#row + 1] = ui.text{ text = m.time, font = FONT, size = 14 * s, color = INK }
    return ui.row(row)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 13 * scale(ctx) }, "elevatedSurface")
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
