-- Prairie Sky look: Wayline's structure under a big sky (shaders/sky.metal). Chips become round,
-- translucent pebbles so the sky shows through; the focused workspace glows like a little sun.
local look = table.clone(require("./wayline-base"))
look.personality = "sky"

local MONO = "Monaspace Neon"
local GLASS = "background/0.55"

local function scale(ctx) return ctx.data.bar.style.height / 40 end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

local function pebble(props, s: number)
    props.fill, props.radius, props.h = GLASS, 14 * s, 28 * s
    props.border, props.borderWidth = "foreground/0.12", 1
    props.hoverOpacity = 0.85
    return props
end

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local hue = if fill == "elevatedSurface" or fill == "accent" then "foreground" else fill
    local row = pebble({ gap = 6 * s, pad = 9 * s, recolor(glyph, hue) }, s)
    if label then
        row[#row + 1] = ui.text{ text = label, font = MONO, size = 13 * s, weight = "semibold", color = hue }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    local warn = pill.border == "warning" -- the crew pill marks "needs you" with a warning border; keep it
    pebble(pill, scale(ctx))
    if warn then pill.border, pill.borderWidth = "warning", 1.5 end
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    local size = 24 * m.scale
    return ui.stack{ w = size, h = size, radius = size / 2,
        fill = if focused then "yellow" else GLASS, border = if focused then nil else "foreground/0.15", borderWidth = 1,
        shadow = if focused then "yellow/0.7" else nil, shadowRadius = 10,
        pulse = if focused then { key = workspace.id, duration = 0.5, scale = { -0.5, 0.15, -0.04, 0 } } else nil,
        ui.text{ text = workspace.name, font = MONO, size = 12 * m.scale, weight = "bold",
            color = if focused then "#1c1917" elseif #workspace.windows > 0 then "foreground" else "mutedForeground" } }
end

look.workspaceMetrics = function(_, style, m)
    return { item = 28 * m.scale, focusCue = false }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius = nil, nil, 14 * m.scale
    pill.gap = 4 * m.scale
    pill.hover = "foreground/0.08"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = pebble({ gap = 6 * s, pad = 8 * s }, s)
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 18 * s, h = 18 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = m.title, size = 13 * s, weight = "semibold", color = "foreground",
            maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = pebble({ gap = 8 * s, pad = 10 * s }, s)
    if m.showDate then
        row[#row + 1] = ui.text{ text = m.date, font = MONO, size = 12 * s, color = "secondaryForeground" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = MONO, size = 14 * s, weight = "bold", color = "foreground" }
    return ui.row(row)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 14 * scale(ctx), color = "foreground" }, "accent")
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
