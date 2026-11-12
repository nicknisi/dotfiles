-- Outrun look: Wayline's structure in neon. Tube-light outlines alternate between the pack's purple and
-- teal and glow, every label is Monaspace, and the focused workspace lights up like a sign. The backdrop
-- (shaders/outrun.metal) races a perspective grid toward a striped synthwave sun.
local look = table.clone(require("./wayline-base"))
look.personality = "outrun"

local MONO = "Monaspace Neon"
local PINK, CYAN = "purple", "teal"

local function scale(ctx) return ctx.data.bar.style.height / 40 end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

local function neon(props, hue: string, s: number)
    props.fill, props.radius, props.h = "background/0.35", 5, 26 * s
    props.border, props.borderWidth = hue, 1.5
    props.shadow, props.shadowRadius = hue .. "/0.8", 8
    props.hoverOpacity = 0.85
    return props
end

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local hue = if fill == "elevatedSurface" or fill == "accent" then PINK else fill
    local row = neon({ gap = 6 * s, pad = 8 * s, recolor(glyph, "foreground") }, hue, s)
    if label then
        row[#row + 1] = ui.text{ text = label, font = MONO, size = 13 * s, weight = "semibold", color = "foreground",
            shadow = hue, shadowRadius = 6 }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    local warn = pill.border == "warning"
    neon(pill, if warn then "warning" else CYAN, scale(ctx))
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    local hue = if focused then PINK else CYAN
    return ui.stack{ w = 24 * m.scale, h = 24 * m.scale, radius = 4,
        fill = if focused then PINK else "background/0.35", border = hue, borderWidth = 1.5,
        shadow = hue .. (if focused then "/0.9" else "/0.5"), shadowRadius = if focused then 12 else 6,
        ui.text{ text = workspace.name, font = MONO, size = 12 * m.scale, weight = "bold",
            color = if focused then "background" else "foreground" } }
end

look.workspaceMetrics = function(_, style, m)
    return { item = 28 * m.scale, focusCue = false }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius, pill.gap = nil, nil, 5, 4 * m.scale
    pill.hover = "teal/0.12"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = neon({ gap = 6 * s, pad = 8 * s }, CYAN, s)
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 16 * s, h = 16 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = string.lower(m.title), font = MONO, size = 12 * s, color = "foreground",
            maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = neon({ gap = 8 * s, pad = 9 * s }, PINK, s)
    if m.showDate then
        row[#row + 1] = ui.text{ text = m.date, font = MONO, size = 11 * s, color = "foreground/0.8" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = MONO, size = 14 * s, weight = "bold", color = "foreground",
        shadow = PINK, shadowRadius = 8 }
    return ui.row(row)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 13 * scale(ctx) }, PINK)
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
