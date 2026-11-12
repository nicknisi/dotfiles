-- Arcade look: Wayline's structure as an 8-bit cabinet HUD. Press Start 2P everywhere, no chip frames,
-- workspaces as stages, a blinking 1UP before the clock, hearts for the battery and space invaders for the
-- crew (in the agents widget). The backdrop (shaders/arcade.metal) is a twinkling starfield.
local look = table.clone(require("./wayline-base"))
look.personality = "arcade"

local PIXEL = "Press Start 2P"

local function scale(ctx) return ctx.data.bar.style.height / 40 end

local function recolor(glyph, hue: string)
    if glyph.fill ~= nil then glyph.fill = hue else glyph.color = hue end
    return glyph
end

-- 1UP blinks: a 30s square wave keyed to the 30s render window (scale -1 hides it).
local BLINK = {}
for i = 0, 240 do BLINK[i + 1] = if (i / 240 * 30) % 1 < 0.6 then 0 else -1 end
BLINK[#BLINK] = 0

look.chip = function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local s = scale(ctx)
    local hue = if fill == "elevatedSurface" then "mutedForeground" elseif fill == "accent" then "yellow" else fill
    local row = { gap = 6 * s, pad = 4 * s, h = 26 * s, hoverOpacity = 0.7, recolor(glyph, hue) }
    if label then
        row[#row + 1] = ui.text{ text = string.upper(label), font = PIXEL, size = 9 * s, color = hue }
    end
    return ui.row(row)
end

look.pill = function(pill, ctx)
    pill.fill, pill.border, pill.radius, pill.shadow = nil, nil, 0, nil
    pill.h = 26 * scale(ctx)
end

look.workspaceMarker = function(ctx, workspace, style, m, occupied)
    if m.compact and not style.labels then return nil end
    local focused = workspace.focused
    return ui.row{ h = 24 * m.scale, gap = 2 * m.scale,
        ui.text{ text = if focused then "▶" else " ", size = 9 * m.scale, color = "yellow" },
        ui.text{ text = workspace.name, font = PIXEL, size = 10 * m.scale,
            color = if focused then "yellow" elseif #workspace.windows > 0 then "foreground" else "mutedForeground" } }
end

look.workspaceMetrics = function(_, style, m)
    return { item = 24 * m.scale, focusCue = false }
end

look.workspacePill = function(pill, workspace, style, m, occupied)
    pill.fill, pill.border, pill.radius, pill.gap = nil, nil, 0, 2 * m.scale
    pill.hover = "yellow/0.12"
end

look.activeWindowBar = function(ctx, m)
    local s = scale(ctx)
    local props = { h = 26 * s, gap = 6 * s, pad = 4 * s }
    if m.showIcon then
        props[#props + 1] = ui.icon{ app = m.bundle, w = 16 * s, h = 16 * s, placeholder = "app.dashed" }
    end
    if m.showText then
        props[#props + 1] = ui.text{ text = string.upper(m.title), font = PIXEL, size = 8 * s, color = "mutedForeground",
            maxWidth = m.maxWidth }
    end
    return ui.row(props)
end

look.clockBar = function(ctx, m)
    local s = scale(ctx)
    local row = { h = 26 * s, gap = 8 * s, pad = 4 * s, hoverOpacity = 0.7,
        ui.text{ text = "1UP", font = PIXEL, size = 9 * s, color = "red",
            pulse = { key = math.floor(ctx.data.seconds / 30), duration = 30, scale = BLINK } } }
    if m.showDate and string.find(m.date, " · ", 1, true) then
        row[#row + 1] = ui.text{ text = string.upper(m.date), font = PIXEL, size = 8 * s, color = "yellow" }
    end
    row[#row + 1] = ui.text{ text = m.time, font = PIXEL, size = 10 * s, color = "foreground" }
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
