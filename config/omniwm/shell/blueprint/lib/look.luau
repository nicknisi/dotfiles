-- Blueprint look: a technical drawing of your own bar. Thin square outlines on a drafting grid
-- (shaders/blueprint.metal), Monaspace everywhere, round workspace markers like detail callouts, and small
-- dimension labels on the window title and clock.
local look = table.clone(require("./wayline-base"))
look.personality = "blueprint"

local MONO = "Monaspace Neon"

local function scale(ctx) return ctx.data.bar.style.height / 40 end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

local function outline(props, s: number)
    props.fill, props.radius, props.h = nil, 0, 24 * s
    props.border, props.borderWidth = "foreground/0.6", 1
    props.hoverOpacity = 0.8
    return props
end

-- A drawing callout: the element with a tiny label set into its top edge.
local function dimension(body, label: string, s: number)
    return ui.stack{ h = 34 * s, body,
        ui.row{ align = "top", dy = 1 * s, pad = 2 * s, fill = "background/0.0",
            ui.text{ text = label, font = MONO, size = 7 * s, color = "foreground/0.7" } } }
end

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local ink = if fill == "elevatedSurface" or fill == "accent" then "foreground" else fill
    local row = outline({ gap = 5 * s, pad = 7 * s, recolor(glyph, ink) }, s)
    if label then
        row[#row + 1] = ui.text{ text = label, font = MONO, size = 12 * s, color = ink }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    local warn = pill.border == "warning"
    outline(pill, scale(ctx))
    if warn then pill.border = "warning" end
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    local size = 22 * m.scale
    return ui.stack{ w = size, h = size, radius = size / 2, fill = if focused then "foreground" else nil,
        border = "foreground/" .. (if #workspace.windows > 0 or focused then "0.8" else "0.35"), borderWidth = 1,
        ui.text{ text = workspace.name, font = MONO, size = 11 * m.scale, weight = "bold",
            color = if focused then "background" else "foreground" } }
end

look.workspaceMetrics = function(_, style, m)
    return { item = 26 * m.scale, focusCue = false }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius, pill.gap = nil, nil, 0, 3 * m.scale
    pill.hover = "foreground/0.08"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = outline({ gap = 6 * s, pad = 7 * s }, s)
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 16 * s, h = 16 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = m.title, font = MONO, size = 12 * s, color = "foreground", maxWidth = m.maxWidth }
    end
    return dimension(ui.row(props), "WINDOW", s)
end

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = outline({ gap = 8 * s, pad = 8 * s }, s)
    if m.showDate then
        row[#row + 1] = ui.text{ text = m.date, font = MONO, size = 11 * s, color = "foreground/0.75" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = MONO, size = 13 * s, weight = "bold", color = "foreground" }
    return dimension(ui.row(row), "T", s)
end

look.controlCenterBar = function(ctx, m)
    return look.chip(ctx, ui.symbol{ name = m.symbol, size = 13 * scale(ctx), color = "foreground" }, "accent")
end

-- Letters only, so the groups sit closer together than Wayline's icon groups.
look.workspaceGroup = function(_, pills, _, _, m)
    pills.gap = 1 * m.scale
    return if m.vertical then ui.column(pills) else ui.row(pills)
end

return require("./skin")(look)
