-- Phosphor look: Wayline's structure as a green-screen terminal. Chips and pills are outlined and glow
-- in the pack's accent, every label is Monaspace, workspaces are square terminal tabs, the clock ends in
-- a blinking block cursor and the crew are ASCII faces. The backdrop is shaders/phosphor-scan.metal.
local look = table.clone(require("./wayline-base"))
look.personality = "phosphor"

local MONO = "Monaspace Neon"

local function scale(ctx) return ctx.data.bar.style.height / 40 end

-- Outlined, glowing frame shared by chips and pills.
local function frame(props, hue: string)
    props.fill, props.radius = nil, 3
    props.border, props.borderWidth = hue .. "/0.55", 1
    props.shadow, props.shadowRadius = hue .. "/0.35", 6
    props.hoverOpacity = 0.85
    return props
end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local hue = if fill == "elevatedSurface" then "mutedForeground" else fill
    local row = frame({ gap = 6 * s, pad = 7 * s, h = 28 * s, recolor(glyph, hue) }, hue)
    if label then
        row[#row + 1] = ui.text{ text = label, font = MONO, size = 13 * s, weight = "semibold",
            color = if labelColor == "elevatedSurface" then "mutedForeground" else labelColor or hue }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    local s = scale(ctx)
    local hue = if pill.border == "warning" then "warning" else "accent"
    frame(pill, hue)
    pill.h = 28 * s
end

-- Square terminal tabs: the focused one is a solid accent block, the rest are dim outlines.
look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    local hue = if focused or #workspace.windows > 0 then "accent" else "mutedForeground"
    return ui.stack{ w = if utf8.len(workspace.name) <= 2 then 26 * m.scale else nil, h = 26 * m.scale, radius = 2,
        fill = if focused then "accent" else nil, border = if focused then nil else hue .. "/0.45", borderWidth = 1,
        shadow = if focused then "accent/0.5" else nil, shadowRadius = 8,
        ui.row{ ui.box{ w = 4 * m.scale, h = 1 },
            ui.text{ text = workspace.name, font = MONO, size = 13 * m.scale, weight = "bold",
                color = if focused then "background" else hue },
            ui.box{ w = 4 * m.scale, h = 1 } } }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.gap, pill.radius = 4 * m.scale, 3
    pill.fill, pill.border = nil, nil -- the tab is the outline; no box around the box
    pill.hover = "accent/0.12"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = frame({ h = 28 * s, gap = 6 * s, pad = 6 * s }, "accent")
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 20 * s, h = 20 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = m.title, font = MONO, size = 13 * s, color = "accent", maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

-- A block cursor that blinks: a pulse plays once per key, so a 30s square wave keyed to the 30s window
-- loops forever (scale -1 collapses it).
local BLINK = {}
for i = 0, 240 do
    BLINK[i + 1] = if (i / 240 * 30) % 1 < 0.55 then 0 else -1
end
BLINK[#BLINK] = 0

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = frame({ h = 28 * s, gap = 8 * s, pad = 8 * s }, "accent")
    if m.showDate then
        row[#row + 1] = ui.text{ text = m.date, font = MONO, size = 12 * s, color = "accent/0.8" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = MONO, size = 14 * s, weight = "bold", color = "accent" }
    row[#row + 1] = ui.box{ w = 7 * s, h = 14 * s, fill = "accent", shadow = "accent/0.6", shadowRadius = 6,
        pulse = { key = math.floor(ctx.data.seconds / 30), duration = 30, scale = BLINK } }
    return ui.row(row)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 15 * scale(ctx), weight = "semibold", color = "accent" },
        "accent")
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
