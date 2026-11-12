-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local function line(vertical, props)
    return vertical and ui.column(props) or ui.row(props)
end

local function spacer(vertical, length)
    return vertical and ui.box{ w = 1, h = length } or ui.box{ w = length, h = 1 }
end

local function supported(m)
    return m.indicator == "pills" or m.indicator == "underline"
end

local function filled(style, m, focused)
    return focused and style.accents and style.backgrounds and m.indicator ~= "underline"
end

local function labelColor(style, m, workspace)
    if style.textColor ~= nil then
        return "foreground"
    end
    if filled(style, m, workspace.focused) then
        return "accentForeground"
    end
    if workspace.focused then
        return style.accents and "accent" or "foreground"
    end
    return style.accents and "accent" or (#workspace.windows > 0 and "secondaryForeground" or "mutedForeground")
end

local function statsArc(value)
    local radius = 24.5
    local top = "M27 2.5"
    if value >= 0.999 then
        return top .. " A24.5 24.5 0 1 1 27 51.5 A24.5 24.5 0 1 1 27 2.5"
    end
    if value <= 0.005 then
        return nil
    end
    local angle = value * 2 * math.pi
    return string.format("%s A24.5 24.5 0 %d 1 %.2f %.2f", top, angle > math.pi and 1 or 0,
        27 + radius * math.sin(angle), 27 - radius * math.cos(angle))
end

local function statsGauge(metric, hue, width)
    local dial = { w = 54, h = 54, help = metric.detail,
        ui.path{ w = 54, h = 54, viewBox = { 0, 0, 54, 54 }, d = statsArc(1),
            border = "foreground/0.08", borderWidth = 5 } }
    local sweep = metric.value and statsArc(metric.value)
    if sweep then
        dial[#dial + 1] = ui.path{ w = 54, h = 54, viewBox = { 0, 0, 54, 54 }, d = sweep,
            border = metric.warn and "red" or (metric.hot and "warning" or hue), borderWidth = 5 }
    end
    dial[#dial + 1] = ui.text{ text = metric.percent, style = "rounded", size = 14, weight = "bold",
        color = "foreground" }
    local props = { w = width, gap = 6, center = true, ui.stack(dial),
        ui.text{ text = metric.title, size = 12, weight = "bold", color = "mutedForeground", maxWidth = width - 4 } }
    if metric.temperatureText then
        props[#props + 1] = ui.text{ text = metric.temperatureText, style = "mono", size = 10,
            color = metric.hot and "warning" or "secondaryForeground" }
    end
    return ui.column(props)
end

local function statsTile(symbol, hue, size)
    size = size or 24
    return ui.stack{ w = size, h = size, radius = 6, fill = hue .. "/0.16",
        ui.symbol{ name = symbol, size = size / 2 - 1, weight = "semibold", color = hue } }
end

local function statsDetail(symbol, hue, title, value, width, lines)
    local row = { w = width, gap = 10, statsTile(symbol, hue) }
    if title then
        row[#row + 1] = ui.text{ text = title, size = 13, weight = "semibold", color = "foreground" }
        row[#row + 1] = ui.box{ grow = 1, h = 1 }
        row[#row + 1] = ui.text{ text = value, size = 12, weight = "medium", color = "secondaryForeground",
            maxWidth = width - 125, lines = lines or 1 }
    else
        row[#row + 1] = ui.text{ text = value, size = 12, weight = "medium", color = "secondaryForeground",
            maxWidth = width - 34, lines = lines or 1 }
    end
    return ui.row(row)
end

local function statsCard(width, children)
    children.w, children.pad, children.gap = width, 10, 10
    children.radius, children.fill, children.center = 9, "elevatedSurface", false
    return ui.column(children)
end

local HOVER = "foreground/0.07"

local function caps(text)
    return if string.find(text, "[\128-\255]") then text else string.upper(text)
end

local function chip(size, vertical, color, glyph, alone)
    local radius = math.floor(size * 0.24)
    local props = { w = size, h = size,
        ui.box{ w = size, h = size, radius = radius, fill = color } }
    if not alone then
        props[#props + 1] = ui.box{ align = vertical and "bottom" or "trailing", w = vertical and size or radius,
            h = vertical and radius or size, fill = color }
    end
    props[#props + 1] = glyph.kind and glyph or ui.symbol(glyph)
    return ui.stack(props)
end

local function standaloneChip(size, vertical, color, glyph)
    local node = chip(size, vertical, color, glyph, true)
    node.hoverOpacity = 0.9
    return node
end

local function symbolChip(ctx, m)
    local style = ctx.data.bar.style
    local size = 32 * style.height / 40
    return standaloneChip(size, style.vertical, "accent",
        { name = m.symbol, size = size * 0.54, weight = "semibold", color = "accentForeground" })
end

local function frame(width, bandHeight, header, body, attach)
    return ui.column{ w = width, gap = 0, material = "clear", attach = attach, radius = 12, fill = "surface",
        border = "border", borderWidth = 1, center = false,
        ui.stack{ w = width, h = bandHeight,
            ui.box{ w = width, h = bandHeight, radius = 12, fill = "elevatedSurface" },
            ui.box{ align = "bottom", w = width, h = 12, fill = "elevatedSurface" }, header },
        ui.box{ w = width, h = 1, fill = "border" }, body }
end

local function titledPanel(_, props, gap)
    local width = props.w or 320
    local header = props[1]
    header.h = 44
    local body = { w = width, pad = 12, gap = gap, center = false }
    for index = 2, #props do
        body[#body + 1] = props[index]
    end
    return frame(width, 44, header, ui.column(body))
end

local function controlCenterCards(node)
    if node.fill == "surface" then
        node.fill, node.radius = "elevatedSurface", 9
    end
    for _, child in ipairs(node) do
        controlCenterCards(child)
    end
end

local function dividedCard(props, width, dividerWidth)
    props.w = width or props.w
    props.gap, props.pad, props.radius, props.fill, props.center = 0, 0, 9, "elevatedSurface", true
    for index = #props, 2, -1 do
        table.insert(props, index, ui.box{ w = dividerWidth, h = 1, fill = "foreground/0.07" })
    end
    return ui.column(props)
end

local STATS_HUES = { cpu = "blue", memory = "green", gpu = "purple", disk = "yellow", down = "accent", up = "red" }

local function compactStatsMeter(ctx, entry, variant)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local hue = entry.hot and "red" or STATS_HUES[entry.key]
    local library = require("./stats")
    local glyph = ui.symbol{ name = entry.symbol, size = math.floor(size * 0.52), weight = "semibold",
        color = "accentForeground" }
    if variant == "gauge" then
        glyph.size = 10 * scale
        glyph = library.gauge(entry.value, 24 * scale, "accentForeground", glyph)
    end
    local props = { gap = 0, radius = math.floor(size * 0.24),
        fill = style.backgrounds and "elevatedSurface" or nil,
        chip(size, style.vertical, hue, glyph) }
    if style.vertical then
        props.w, props.gap = size, 2 * scale
    else
        props.h = size
        props[#props + 1] = ui.box{ w = 8 * scale, h = 1 }
    end
    if variant == "graph" then
        props[#props + 1] = library.sparkline(entry.history, (style.vertical and 24 or 34) * scale, 14 * scale, hue)
        if not style.vertical then
            props[#props + 1] = ui.box{ w = 6 * scale, h = 1 }
        end
    end
    props[#props + 1] = ui.text{ text = if style.vertical then tostring(entry.value) else ctx.format.percent(entry.value / 100),
        style = "mono", size = 14 * scale, weight = "semibold",
        color = style.textColor ~= nil and "foreground" or hue,
        reserve = if style.vertical then nil else ctx.format.percent(1) }
    props[#props + 1] = spacer(style.vertical, (style.vertical and 3 or 9) * scale)
    return line(style.vertical, props)
end

local function compactStatsPanel(_, m)
    local width, inner = 340, 316
    local rows = {}
    for _, entry in m.rows do
        local hue = STATS_HUES[entry.key]
        rows[#rows + 1] = ui.row{ w = inner, h = 38, gap = 10,
            ui.box{ w = 2, h = 1 }, statsTile(entry.symbol, hue, 26),
            ui.text{ text = entry.label, size = 14, weight = "semibold", grow = 1,
                maxWidth = entry.history and 82 or 124 },
            if entry.history then require("./stats").sparkline(entry.history, 64, 18, hue) else nil,
            ui.text{ text = entry.text, style = "mono", size = 14, weight = "semibold", color = "secondaryForeground",
                maxWidth = entry.history and 82 or 116 },
            ui.box{ w = 2, h = 1 } }
    end
    return ui.column{ w = width, pad = 12, material = "clear", radius = 12, fill = "surface",
        border = "border", borderWidth = 1, center = false, dividedCard(rows, inner, inner - 16) }
end

local function utilityPanel(ctx, m, library, title, symbol, width)
    width = width or 340
    local inner = width - 32
    local content = library.content(ctx, inner, m)
    local header
    if m then
        header = table.remove(content, 1)
        header[1].weight = "bold"
        if m.power == nil or (m.power and (not m.devices or #m.devices > 0)) then
            content[1] = statsCard(inner, content[1])
        end
    else
        header = ui.row{ w = inner, ui.text{ text = title, size = 14, weight = "bold" } }
        content = statsCard(inner, content)
    end
    header.gap = 8
    local glyph = if library.fan then ui.symbol{ name = "wifi", size = 13, weight = "semibold", color = "accent" }
        elseif library.rune then library.rune(14, "accent")
        else ui.symbol{ name = symbol, size = 14, weight = "semibold", color = "accent" }
    table.insert(header, 1, glyph)
    return frame(width, 44, header, ui.column{ w = width, pad = 16, gap = 10, center = false, content })
end

local function worldClockBar(ctx, m)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local props = { gap = 0, radius = math.floor(size * 0.24),
        fill = style.backgrounds and "elevatedSurface" or nil, hoverOpacity = 0.9,
        chip(size, style.vertical, "blue", { name = "globe", size = 18 * scale,
            weight = "semibold", color = "accentForeground" }) }
    if style.vertical then
        props.w, props.gap = size, 2 * scale
        props[#props + 1] = ui.text{ text = string.format("%02d", m.clocks[1].hour), style = "mono",
            size = 14 * scale, weight = "semibold", color = "blue" }
        props[#props + 1] = ui.box{ w = 1, h = 3 * scale }
        return ui.column(props)
    end
    props.h = size
    props[#props + 1] = ui.box{ w = 8 * scale, h = 1 }
    for index = 1, m.shown do
        local clock = m.clocks[index]
        if index > 1 then
            props[#props + 1] = ui.box{ w = 1, h = 14 * scale, fill = "border" }
            props[#props + 1] = ui.box{ w = 8 * scale, h = 1 }
        end
        props[#props + 1] = ui.text{ text = clock.short, size = 11 * scale, weight = "bold", color = "secondaryForeground",
            maxWidth = 45 * scale }
        props[#props + 1] = ui.box{ w = 5 * scale, h = 1 }
        props[#props + 1] = ui.text{ text = clock.time, style = "mono", size = 14 * scale, weight = "semibold",
            color = "blue", reserve = "00:00 PM" }
        props[#props + 1] = ui.box{ w = 9 * scale, h = 1 }
    end
    return ui.row(props)
end

local function batteryChip(ctx, state, details)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local radius = math.floor(size * 0.24)
    local hue = state.low and "red" or (state.charging and "green" or "yellow")
    local mode = details and state.mode or "beside"
    local glyph
    if mode == "inside" then
        local cell = require("./battery").cell(state, 25 * scale, 13 * scale, state.text)
        cell[1].border = "accentForeground/0.7"
        cell[1][1].fill = "accentForeground/0.22"
        cell[1][2].color = "accentForeground"
        cell[2].fill = "accentForeground/0.7"
        glyph = ui.stack{ w = size, h = size, radius = radius, fill = hue,
            cell }
    else
        glyph = chip(size, style.vertical, hue, { name = state.symbol, size = math.floor(size * 0.52),
            weight = "semibold", color = "accentForeground" }, mode ~= "beside")
    end
    local props = { gap = 0, radius = radius,
        fill = (not details or style.backgrounds) and "elevatedSurface" or nil,
        hoverOpacity = details and 0.9 or nil, glyph }
    if mode ~= "beside" then
        props.w, props.h = size, size
        return ui.stack(props)
    end
    if style.vertical then
        props.w, props.gap = size, 2
        props[#props + 1] = ui.text{ text = state.text, style = "mono", size = 14 * scale,
            weight = "semibold", color = hue }
        props[#props + 1] = ui.box{ w = 1, h = 3 }
        return ui.column(props)
    end
    props.h = size
    props[#props + 1] = ui.box{ w = 8, h = 1 }
    props[#props + 1] = ui.text{ text = state.percent, style = "mono", size = 14 * scale, weight = "semibold",
        color = hue, reserve = state.reserve }
    props[#props + 1] = ui.box{ w = 9, h = 1 }
    return ui.row(props)
end

local RADIO_WIDTH = 360

local function radioChip(ctx, library, state)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local glyphSize = 18 * scale
    local glyph
    if library.fan then
        glyph = state.power and library.fan(state.level, glyphSize, "accentForeground", "accentForeground/0.24")
            or ui.symbol{ name = "wifi.slash", size = glyphSize, color = "accentForeground" }
    else
        glyph = library.rune(glyphSize, state.power and "accentForeground" or "accentForeground/0.6")
    end
    return standaloneChip(size, style.vertical, "accent", glyph)
end

local AUDIO_WIDTH = 360
local AUDIO_INNER = AUDIO_WIDTH - 32
local AUDIO_CARD = AUDIO_INNER - 20
local AUDIO_WELL = "foreground/0.06"

local function audioWell(size, selected, child)
    return ui.stack{ w = size, h = size, radius = 7, fill = selected and "accent/0.16" or AUDIO_WELL, child }
end

local function audioMute(symbol, command, muted)
    return ui.stack{ w = 28, h = 28, radius = 7, fill = muted and "error/0.16" or AUDIO_WELL,
        hover = HOVER, onClick = command,
        ui.symbol{ name = symbol, size = 12, weight = "semibold",
            color = muted and "error" or "secondaryForeground" } }
end

local function audioCard(rows)
    return dividedCard(rows, AUDIO_INNER, AUDIO_CARD)
end

local function audioApp(app)
    return ui.column{ w = AUDIO_CARD, gap = 6, pad = 0, center = false,
        ui.box{ w = 1, h = 4 },
        ui.row{ w = AUDIO_CARD, gap = 10,
            audioWell(28, false, ui.icon{ app = app.id, w = 18, h = 18,
                opacity = app.playing and 1 or 0.55 }),
            ui.text{ text = app.name, size = 14, weight = "semibold",
                color = app.muted and "mutedForeground" or "foreground", maxWidth = 150 },
            ui.box{ grow = 1, h = 1 },
            ui.row{ w = 40, ui.box{ grow = 1, h = 1 },
                ui.text{ text = app.percent, style = "mono", size = 12, weight = "semibold",
                    color = "mutedForeground" } },
            audioMute(app.symbol, app.mute, app.muted) },
        ui.row{ w = AUDIO_CARD, gap = 0,
            ui.box{ w = 38, h = 1 },
            ui.slider{ value = app.level, w = AUDIO_CARD - 38, h = 14,
                color = app.muted and "mutedForeground" or "accent", onChange = app.set } },
        ui.box{ w = 1, h = 6 } }
end

local MEDIA_WIDTH = 360
local MEDIA_INNER = MEDIA_WIDTH - 32

local function mediaButton(symbol, command, size, active)
    return ui.stack{ w = size + 18, h = size + 18, radius = (size + 18) / 2,
        fill = active and "accent/0.15" or nil, hover = "foreground/0.08", onClick = command,
        ui.symbol{ name = symbol, size = size, weight = "semibold",
            color = active and "accent" or "secondaryForeground" } }
end

local function mediaLyrics(lyrics)
    if not lyrics then
        return nil
    end
    local width = MEDIA_INNER - 20
    local rows = { w = width, pad = 0, gap = 4, center = false, ui.box{ w = 1, h = 4 } }
    if lyrics.visible then
        for _, entry in lyrics.visible do
            rows[#rows + 1] = ui.row{ w = width, pad = 6, radius = 6,
                fill = entry.current and "accent/0.12" or nil, hover = HOVER,
                onClick = entry.seek,
                ui.text{ text = entry.text, size = 13,
                    weight = entry.current and "semibold" or "medium",
                    color = entry.current and "accent" or "secondaryForeground", maxWidth = width - 12, lines = 2 } }
        end
    else
        rows[#rows + 1] = ui.text{ text = lyrics.message,
            size = 13, color = "secondaryForeground", maxWidth = width }
    end
    rows[#rows + 1] = ui.box{ w = 1, h = 4 }
    return dividedCard({
        ui.row{ w = width, h = 32,
            ui.text{ text = caps(omniwm.l10n("Lyrics")), size = 12, weight = "bold", color = "mutedForeground" } },
        ui.column(rows) }, MEDIA_INNER, width)
end

local WEATHER_WIDTH = 480
local WEATHER_INNER = WEATHER_WIDTH - 32
local WEATHER_CARD = WEATHER_INNER - 20
local WEATHER_RANGE = 120
local WEATHER_TINTS = {
    Clear = "yellow",
    ["Partly cloudy"] = "yellow",
    Overcast = "secondaryForeground",
    Fog = "secondaryForeground",
    Drizzle = "blue",
    ["Freezing rain"] = "cyan",
    Rain = "blue",
    Snow = "foreground",
    Thunderstorms = "accent",
}

local function weatherTint(kind)
    return WEATHER_TINTS[kind] or "mutedForeground"
end

local function weatherStat(symbol, color, text, width)
    return ui.column{ w = width, gap = 5, pad = 0, center = true,
        ui.box{ w = 1, h = 6 },
        ui.symbol{ name = symbol, size = 15, weight = "semibold", color = color },
        ui.text{ text = text, size = 12, weight = "semibold", color = "foreground", maxWidth = width - 12, lines = 2 },
        ui.box{ w = 1, h = 6 } }
end

local function weatherStats(m)
    local cells = {}
    if m.feels then
        cells[#cells + 1] = { "thermometer.medium", "orange", m.feels }
    end
    if m.rain then
        cells[#cells + 1] = { "umbrella.fill", "blue", m.rain }
    end
    if m.wind then
        cells[#cells + 1] = { "wind", "teal", m.wind }
    end
    if #cells == 0 then
        return nil
    end
    local width = (WEATHER_INNER - (#cells - 1)) / #cells
    local row = { w = WEATHER_INNER, gap = 0, radius = 9, fill = "elevatedSurface" }
    for index, cell in cells do
        if index > 1 then
            row[#row + 1] = ui.box{ w = 1, h = 40, fill = "foreground/0.08" }
        end
        row[#row + 1] = weatherStat(cell[1], cell[2], cell[3], width)
    end
    return ui.row(row)
end

local function weatherHourly(hours)
    local count = #hours
    if count == 0 then
        return nil
    end
    local width = math.floor((WEATHER_INNER - 8) / count)
    local strip = { w = WEATHER_INNER, gap = 0, pad = 4, radius = 9, fill = "elevatedSurface" }
    for index, hour in hours do
        strip[#strip + 1] = ui.column{ w = width, gap = 5, pad = 0, radius = 7, center = true,
            fill = index == 1 and "accent/0.14" or nil, help = hour.condition,
            ui.box{ w = 1, h = 4 },
            ui.text{ text = hour.label, size = 12, weight = "semibold",
                color = index == 1 and "accent" or "mutedForeground" },
            ui.symbol{ name = hour.symbol, size = 13, weight = "medium", color = weatherTint(hour.kind) },
            ui.text{ text = hour.temp, style = "mono", size = 12, weight = "semibold", color = "foreground" },
            ui.box{ w = 1, h = 4 } }
    end
    return ui.row(strip)
end

local function weatherRange(day)
    local from = math.floor(day.from * WEATHER_RANGE)
    local to = math.max(from + 6, math.floor(day.to * WEATHER_RANGE))
    local half = (to - from) / 2
    return ui.stack{ w = WEATHER_RANGE, h = 4, radius = 2, fill = "foreground/0.08",
        ui.row{ align = "leading", dx = from, gap = 0,
            ui.box{ w = half, h = 4, radius = 2, fill = "blue" },
            ui.box{ w = to - from - half, h = 4, radius = 2, fill = "yellow" } } }
end

local function weatherDaily(days)
    if #days == 0 then
        return nil
    end
    local rows = {}
    for index, day in days do
        rows[#rows + 1] = ui.row{ w = WEATHER_CARD, h = 34, gap = 8,
            ui.text{ text = day.label, size = 14, weight = index == 1 and "bold" or "medium",
                color = index == 1 and "accent" or "foreground", w = 70, maxWidth = 70 },
            ui.stack{ w = 20, h = 20, help = day.condition,
                ui.symbol{ name = day.symbol, size = 14, weight = "medium", color = weatherTint(day.kind) } },
            ui.text{ text = day.rain or "", style = "mono", size = 12, weight = "semibold", color = "blue", w = 34 },
            ui.box{ grow = 1, h = 1 },
            ui.row{ w = 30, ui.box{ grow = 1, h = 1 },
                ui.text{ text = day.low, style = "mono", size = 14, weight = "medium", color = "mutedForeground" } },
            weatherRange(day),
            ui.row{ w = 30, ui.box{ grow = 1, h = 1 },
                ui.text{ text = day.high, style = "mono", size = 14, weight = "bold", color = "foreground" } } }
    end
    return dividedCard(rows, WEATHER_INNER, WEATHER_CARD)
end

local function weatherBar(ctx, m)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local item = { gap = 0, radius = math.floor(size * 0.24), fill = "elevatedSurface", hoverOpacity = 0.9,
        chip(size, style.vertical, "accent", { name = m.symbol, size = math.floor(size * 0.54),
            weight = "semibold", color = "accentForeground" }) }
    if style.vertical then
        item.w, item.gap = size, 2
        item[#item + 1] = ui.text{ text = m.temp, style = "mono", size = 14 * scale, weight = "semibold", color = "accent" }
        item[#item + 1] = ui.box{ w = 1, h = 3 }
        return ui.column(item)
    end
    item.h = size
    item[#item + 1] = ui.box{ w = 8, h = 1 }
    item[#item + 1] = ui.text{ text = m.temp, style = "mono", size = 14 * scale, weight = "semibold",
        color = "accent", reserve = "-00°" }
    item[#item + 1] = ui.box{ w = 8, h = 1 }
    return ui.row(item)
end

local function weatherPanel(_, m)
    if not m then
        return nil
    end
    local header = { w = WEATHER_INNER, gap = 8,
        ui.symbol{ name = "location.fill", size = 12, weight = "semibold", color = "accent" },
        ui.text{ text = m.place or m.condition, size = 14, weight = "bold", color = "foreground", maxWidth = 240 },
        ui.box{ grow = 1, h = 1 } }
    if m.stale then
        header[#header + 1] = ui.symbol{ name = "exclamationmark.triangle.fill", size = 12, color = "warning",
            help = m.stale }
    end
    local extremes = { gap = 4, center = false }
    if m.high then
        extremes[#extremes + 1] = ui.row{ gap = 4,
            ui.symbol{ name = "arrow.up", size = 10, weight = "bold", color = "orange" },
            ui.text{ text = m.high, size = 14, weight = "semibold", color = "foreground" } }
        extremes[#extremes + 1] = ui.row{ gap = 4,
            ui.symbol{ name = "arrow.down", size = 10, weight = "bold", color = "blue" },
            ui.text{ text = m.low, size = 14, weight = "semibold", color = "secondaryForeground" } }
    end
    local body = { w = WEATHER_WIDTH, pad = 16, gap = 10, center = false,
        ui.row{ w = WEATHER_INNER, gap = 14,
            ui.stack{ w = 52, h = 52, ui.symbol{ name = m.symbol, size = 40, weight = "regular",
                color = weatherTint(m.kind) } },
            ui.column{ gap = 0, center = false,
                ui.text{ text = m.temp, style = "rounded", size = 36, weight = "light", color = "foreground" },
                ui.text{ text = m.condition, size = 14, weight = "medium", color = "secondaryForeground", maxWidth = 200 } },
            ui.box{ grow = 1, h = 1 }, ui.column(extremes) } }
    body[#body + 1] = weatherStats(m)
    body[#body + 1] = weatherHourly(m.hours)
    body[#body + 1] = weatherDaily(m.days)
    local footer = { w = WEATHER_INNER, gap = 6 }
    if m.stale then
        footer[#footer + 1] = ui.symbol{ name = "exclamationmark.triangle", size = 10, color = "warning" }
        footer[#footer + 1] = ui.text{ text = m.stale, size = 12, weight = "semibold",
            color = "warning" }
        footer[#footer + 1] = ui.box{ grow = 1, h = 1 }
    end
    footer[#footer + 1] = ui.text{ text = m.attribution, size = 12, weight = "medium", color = "mutedForeground" }
    body[#body + 1] = ui.row(footer)
    return frame(WEATHER_WIDTH, 44, ui.row(header), ui.column(body))
end

local CALENDAR_CELL = 38
local CALENDAR_GRID = CALENDAR_CELL * 7
local CALENDAR_WIDTH = CALENDAR_GRID + 16 + 32
local CALENDAR_INNER = CALENDAR_WIDTH - 32
local CALENDAR_CARD = CALENDAR_INNER - 20

local function clockBar(ctx, m)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local radius = math.floor(size * 0.24)
    local rows = { gap = 0, radius = radius, fill = "elevatedSurface", hoverOpacity = 0.9 }
    if m.showIcon then
        rows[#rows + 1] = chip(size, style.vertical, "accent", { name = "clock.fill",
            size = math.floor(size * 0.54), weight = "semibold", color = "accentForeground" })
    end
    if style.vertical then
        rows.w, rows.gap = size, 2
        if not m.showIcon then
            rows[#rows + 1] = ui.box{ w = 1, h = 3 }
        end
        rows[#rows + 1] = ui.text{ text = m.hour, style = "mono", size = 14 * scale, weight = "bold", color = "accent" }
        rows[#rows + 1] = ui.text{ text = m.minute, style = "mono", size = 14 * scale, weight = "semibold", color = "accent" }
        if m.meridiem then
            rows[#rows + 1] = ui.text{ text = m.meridiem, style = "mono", size = 9 * scale,
                color = "secondaryForeground" }
        end
        rows[#rows + 1] = ui.box{ w = 1, h = 3 }
        return ui.column(rows)
    end
    rows.h = size
    rows[#rows + 1] = ui.box{ w = 8, h = 1 }
    if m.showDate then
        rows[#rows + 1] = ui.text{ text = m.date, size = 12 * scale, weight = "medium", color = "accent" }
        rows[#rows + 1] = ui.box{ w = 6, h = 1 }
    end
    rows[#rows + 1] = ui.text{ text = m.time, style = "mono", size = 14 * scale, weight = "bold", color = "accent",
        reserve = "00:00 PM" }
    rows[#rows + 1] = ui.box{ w = 9, h = 1 }
    return ui.row(rows)
end

local function calendarBar(ctx, m)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local event = m.event
    local props = { gap = 0, radius = math.floor(size * 0.24), fill = "elevatedSurface", hoverOpacity = 0.9,
        chip(size, style.vertical, "accent", { name = "calendar", size = math.floor(size * 0.52),
            weight = "semibold", color = "accentForeground" }, not event) }
    if style.vertical then
        props.w = size
        if event then
            props.gap = 3
            props[#props + 1] = ui.box{ w = 6, h = 6, radius = 3, fill = event.color }
            props[#props + 1] = ui.box{ w = 1, h = 2 }
        end
        return ui.column(props)
    end
    props.h = size
    if event then
        props[#props + 1] = ui.box{ w = 8, h = 1 }
        props[#props + 1] = ui.box{ w = 6, h = 6, radius = 3, fill = event.color }
        props[#props + 1] = ui.box{ w = 6, h = 1 }
        props[#props + 1] = ui.text{ text = event.title, size = 14 * scale, weight = "semibold", color = "accent",
            maxWidth = 130 }
        props[#props + 1] = ui.box{ w = 6, h = 1 }
        props[#props + 1] = ui.text{ text = event.countdown, size = 12 * scale, weight = "medium",
            color = "secondaryForeground" }
        props[#props + 1] = ui.box{ w = 9, h = 1 }
    end
    return ui.row(props)
end

local function calendarButton(symbol, command)
    return ui.stack{ w = 26, h = 26, radius = 7, hover = HOVER, onClick = command,
        ui.symbol{ name = symbol, size = 11, weight = "bold", color = "secondaryForeground" } }
end

local function calendarGrid(month, scroll)
    local rows = { w = CALENDAR_GRID + 16, gap = 0, pad = 8, radius = 9, fill = "elevatedSurface",
        center = false, onScroll = scroll }
    local header = { gap = 0 }
    for _, symbol in month.weekdays do
        header[#header + 1] = ui.stack{ w = CALENDAR_CELL, h = 22,
            ui.text{ text = symbol, size = 12, weight = "bold", color = "mutedForeground" } }
    end
    rows[#rows + 1] = ui.row(header)
    local week = { gap = 0 }
    for _ = 1, month.offset do
        week[#week + 1] = ui.box{ w = CALENDAR_CELL, h = CALENDAR_CELL }
    end
    for day = 1, month.days do
        local today = day == month.today
        week[#week + 1] = ui.stack{ w = CALENDAR_CELL, h = CALENDAR_CELL,
            ui.stack{ w = 28, h = 28, radius = 7, fill = if today then "accent" else nil,
                ui.text{ text = tostring(day), style = "mono", size = 14, weight = if today then "bold" else "semibold",
                    color = if today then "accentForeground" else "secondaryForeground" } },
            if month.marked[day] then ui.box{ align = "bottom", dy = -3, w = 4, h = 4, radius = 2,
                fill = if today then "accentForeground" else "accent" } else nil }
        if #week == 7 then
            rows[#rows + 1] = ui.row(week)
            week = { gap = 0 }
        end
    end
    if #week > 0 then
        rows[#rows + 1] = ui.row(week)
    end
    return ui.column(rows)
end

local function calendarAgenda(event)
    local width = if event.countdown then CALENDAR_CARD - 104 else CALENDAR_CARD - 24
    local row = { w = CALENDAR_CARD, gap = 10, pad = 0, radius = 7, hover = HOVER, onClick = event.open,
        ui.box{ w = 1, h = 44 },
        ui.box{ w = 3, h = 28, radius = 1.5, fill = event.color },
        ui.column{ gap = 2, center = false,
            ui.text{ text = event.title, size = 14, weight = "semibold", color = "foreground", maxWidth = width },
            ui.text{ text = event.day .. " · " .. event.when, size = 12, weight = "medium", color = "mutedForeground",
                maxWidth = width } } }
    if event.countdown then
        row[#row + 1] = ui.box{ grow = 1, h = 1 }
        row[#row + 1] = ui.text{ text = event.countdown, size = 12, weight = "semibold", color = "accent", maxWidth = 70 }
    end
    return ui.row(row)
end

local function calendarAction(symbol, text, command, color)
    return ui.row{ w = CALENDAR_CARD, h = 40, gap = 10, radius = 7, hover = HOVER, onClick = command,
        statsTile(symbol, color),
        ui.text{ text = text, size = 14, weight = "semibold", color = "foreground", maxWidth = CALENDAR_CARD - 40,
            lines = 2 } }
end

local function calendarPanel(_, m)
    local header = { w = CALENDAR_INNER, gap = 2,
        ui.symbol{ name = "calendar", size = 13, weight = "semibold", color = "accent" },
        ui.box{ w = 6, h = 1 },
        ui.text{ text = m.month and m.month.title or omniwm.l10n("Calendar"), size = 14, weight = "bold",
            color = "foreground", grow = 1 } }
    local body = { w = CALENDAR_WIDTH, pad = 16, gap = 10, center = false }
    if m.month then
        header[#header + 1] = calendarButton("chevron.left", m.previous)
        header[#header + 1] = calendarButton("circle.fill", m.today)
        header[#header + 1] = calendarButton("chevron.right", m.next)
        body[#body + 1] = calendarGrid(m.month, m.scroll)
    end
    local rows = {}
    for _, event in m.agenda or {} do
        rows[#rows + 1] = calendarAgenda(event)
    end
    if m.agenda and #rows == 0 then
        rows[#rows + 1] = ui.row{ w = CALENDAR_CARD, h = 40,
            ui.text{ text = omniwm.l10n("No upcoming events"), size = 14, weight = "medium", color = "mutedForeground" } }
    elseif m.action then
        rows[#rows + 1] = calendarAction(m.action.symbol, m.action.text, m.action.command,
            if m.access == "notDetermined" then "accent" else "warning")
    end
    rows[#rows + 1] = calendarAction("arrow.up.forward.app", omniwm.l10n("Open Calendar"), m.open, "accent")
    body[#body + 1] = dividedCard(rows, CALENDAR_INNER, CALENDAR_CARD)
    return frame(CALENDAR_WIDTH, 44, ui.row(header), ui.column(body))
end

return require("./skin")({
    base = 40,
    hover = HOVER,
    hiddenBarHover = "accent/0.15",
    width = 320,
    widths = { workspaces = 296, ["system-stats"] = 348, ["control-center"] = 316 },
    size = { text = 14, icon = 24, slot = 28 },
    primaryButton = { w = 40, h = 40, radius = 20, fill = "accent", color = "accentForeground" },
    controlCenterBar = symbolChip,
    controlCenterPanel = function(ctx, props)
        props.w -= 4
        controlCenterCards(props)
        return titledPanel(ctx, props, 10)
    end,
    activeWindowBar = function(ctx, m)
        local style = ctx.data.bar.style
        local scale = style.height / 40
        local size = 32 * scale
        local props = { w = style.vertical and size or nil, h = size, gap = 6 * scale, pad = 4 * scale,
            radius = math.floor(size * 0.24), fill = style.backgrounds and "elevatedSurface" or nil,
            hoverOpacity = 0.9 }
        if m.showIcon then
            props[#props + 1] = ui.icon{ app = m.bundle, w = 24 * scale, h = 24 * scale, placeholder = "app.dashed" }
        end
        if m.showText then
            props[#props + 1] = ui.row{ gap = 0,
                ui.text{ text = m.title, size = 14 * scale, weight = "semibold",
                    color = "foreground", maxWidth = m.maxWidth },
                ui.box{ w = 5 * scale, h = 1 } }
        end
        return line(style.vertical, props)
    end,
    clockBar = clockBar,
    calendarBar = calendarBar,
    calendarPanel = calendarPanel,
    weatherBar = weatherBar,
    weatherPanel = weatherPanel,
    statsBar = function(ctx, m)
        local props = { gap = 6 * ctx.data.bar.style.height / 40 }
        for _, entry in m.meters do
            props[#props + 1] = compactStatsMeter(ctx, entry, m.variant)
        end
        return line(ctx.data.bar.style.vertical, props)
    end,
    statsPanel = compactStatsPanel,
    inputSourceBar = function(ctx, m)
        local size = 32 * ctx.data.bar.style.height / 40
        return standaloneChip(size, ctx.data.bar.style.vertical, "blue",
            ui.text{ text = m.short, size = size * 0.4, weight = "bold", color = "accentForeground", maxWidth = size - 6 })
    end,
    inputSourcePanel = function(ctx, m)
        return utilityPanel(ctx, m, require("./input-source"), omniwm.l10n("Input Sources"), "keyboard")
    end,
    launcherBar = symbolChip,
    privacyBar = function(ctx, m)
        local style = ctx.data.bar.style
        local scale = style.height / 40
        local size = 32 * scale
        local props = { gap = (m.icons and 4 or 6) * scale }
        for _, indicator in m.indicators do
            props[#props + 1] = if m.icons then ui.stack{ w = size, h = size, radius = math.floor(size * 0.24),
                fill = style.backgrounds and "elevatedSurface" or nil,
                ui.symbol{ name = indicator.symbol, size = 17 * scale, weight = "semibold", color = indicator.color } }
                else ui.box{ w = 7 * scale, h = 7 * scale, radius = 3.5 * scale, fill = indicator.color }
        end
        local indicators = line(style.vertical, props)
        return if m.icons then indicators else ui.stack{ w = size, h = size, radius = math.floor(size * 0.24),
            fill = style.backgrounds and "elevatedSurface" or nil, indicators }
    end,
    worldClockBar = worldClockBar,
    worldClockPanel = function(ctx, m)
        return utilityPanel(ctx, m, require("./world-clock"), omniwm.l10n("World Clock"), "globe")
    end,
    wifiBar = function(ctx, state)
        return radioChip(ctx, require("./wifi"), state)
    end,
    bluetoothBar = function(ctx, state)
        return radioChip(ctx, require("./bluetooth"), state)
    end,
    wifiPanel = function(ctx, m)
        return utilityPanel(ctx, m, require("./wifi"), omniwm.l10n("Wi-Fi"), nil, RADIO_WIDTH)
    end,
    bluetoothPanel = function(ctx, m)
        return utilityPanel(ctx, m, require("./bluetooth"), omniwm.l10n("Bluetooth"), nil, RADIO_WIDTH)
    end,
    batteryBar = function(ctx, state)
        return batteryChip(ctx, state, false)
    end,
    batteryDetailsBar = function(ctx, state)
        return batteryChip(ctx, state, true)
    end,
    batteryPanel = function(ctx, m)
        local width = 360
        local inner = width - 32
        local header = ui.row{ w = inner, gap = 8,
            ui.symbol{ name = m and m.symbol or "battery.0percent", size = 14, weight = "semibold", color = "accent" },
            ui.text{ text = omniwm.l10n("Battery"), size = 14, weight = "bold", color = "foreground" } }
        local content = require("./battery").content(ctx, inner, m)
        local count = if m and #m.details > 0 then 2 else 1
        for index = 1, count do
            local card = if m then content[index] else content
            card.radius, card.fill = 9, "elevatedSurface"
        end
        return frame(width, 44, header, ui.column{ w = width, pad = 16, gap = 10, center = false,
            content })
    end,
    mediaBar = function(ctx, m)
        local style = ctx.data.bar.style
        local scale = style.height / 40
        local size = 32 * scale
        local props = { gap = 0, radius = math.floor(size * 0.24),
            fill = style.backgrounds and "elevatedSurface" or nil, hoverOpacity = 0.9,
            chip(size, style.vertical, "blue", { name = m.symbol, size = math.floor(size * 0.46),
                weight = "bold", color = "accentForeground" }) }
        if style.vertical then
            props.w = size
            return ui.column(props)
        end
        props.h = size
        props[#props + 1] = ui.box{ w = 8, h = 1 }
        props[#props + 1] = ui.text{ text = m.title, size = 14 * scale, weight = "semibold",
            color = style.textColor ~= nil and "foreground" or "blue", maxWidth = 150 }
        props[#props + 1] = ui.box{ w = 9, h = 1 }
        return ui.row(props)
    end,
    mediaPanel = function(_, m)
        if not m then
            return ui.column{ w = MEDIA_WIDTH, gap = 0, material = "clear", radius = 12, fill = "surface",
                border = "border", borderWidth = 1, center = false,
                ui.box{ w = MEDIA_WIDTH, pad = 16,
                    ui.text{ text = omniwm.l10n("Nothing is playing"), color = "secondaryForeground" } } }
        end
        local cover = if m.artwork then ui.image{ image = m.artwork, w = 72, h = 72, radius = 8 }
            else ui.stack{ w = 72, h = 72, radius = 8, fill = "elevatedSurface",
                ui.icon{ app = m.bundle, w = 40, h = 40, placeholder = "music.note" } }
        local header = ui.row{ w = MEDIA_INNER, gap = 8,
            ui.icon{ app = m.bundle, w = 16, h = 16, placeholder = "music.note" },
            ui.text{ text = m.app, size = 14, weight = "bold", color = "foreground", maxWidth = MEDIA_INNER - 60 },
            ui.box{ grow = 1, h = 1 },
            ui.stack{ w = 26, h = 26, radius = 6, hover = "foreground/0.08", onClick = m.open,
                ui.symbol{ name = "arrow.up.forward.app", size = 12, color = "secondaryForeground" } } }
        local body = { w = MEDIA_WIDTH, pad = 16, gap = 14, center = false,
            ui.row{ w = MEDIA_INNER, gap = 14, cover,
                ui.column{ gap = 3, center = false,
                    ui.text{ text = m.title, size = 14, weight = "bold", color = "foreground", maxWidth = MEDIA_INNER - 86 },
                    ui.text{ text = m.artist, size = 14, weight = "semibold", color = "secondaryForeground",
                        maxWidth = MEDIA_INNER - 86 },
                    ui.text{ text = m.album, size = 12, weight = "medium", color = "mutedForeground",
                        maxWidth = MEDIA_INNER - 86 } } } }
        if m.duration then
            body[#body + 1] = ui.column{ gap = 5, center = false,
                ui.slider{ value = m.fraction, w = MEDIA_INNER, h = 12, color = "accent", onChange = m.seek },
                ui.row{ w = MEDIA_INNER,
                    ui.text{ text = m.elapsedText, style = "mono", size = 12, weight = "semibold", color = "mutedForeground" },
                    ui.box{ grow = 1, h = 1 },
                    ui.text{ text = m.durationText, style = "mono", size = 12, weight = "semibold", color = "mutedForeground" } } }
        end
        local controls = { w = MEDIA_INNER, gap = 10, ui.box{ grow = 1, h = 1 } }
        if m.shuffle ~= nil then
            controls[#controls + 1] = mediaButton("shuffle", m.shuffleCommand, 13, m.shuffle)
        end
        controls[#controls + 1] = mediaButton("backward.fill", m.previous, 15)
        controls[#controls + 1] = ui.stack{ w = 48, h = 48, radius = 24, fill = "accent", hoverOpacity = 0.85,
            onClick = m.toggle,
            ui.symbol{ name = m.playSymbol, size = 20, weight = "bold", color = "accentForeground" } }
        controls[#controls + 1] = mediaButton("forward.fill", m.next, 15)
        if m.repeatMode ~= nil then
            controls[#controls + 1] = mediaButton(m.repeatSymbol, m.repeatCommand, 13, m.repeating)
        end
        controls[#controls + 1] = ui.box{ grow = 1, h = 1 }
        body[#body + 1] = ui.row(controls)
        body[#body + 1] = mediaLyrics(m.lyrics)
        return frame(MEDIA_WIDTH, 44, header, ui.column(body))
    end,
    volumeBar = function(ctx, m)
        local style = ctx.data.bar.style
        local scale = style.height / 40
        local size = 32 * scale
        local radius = math.floor(size * 0.24)
        local block = chip(size, style.vertical, "red", { name = m.symbol, size = math.floor(size * 0.52),
            weight = "semibold", color = "accentForeground" })
        local hue = style.textColor ~= nil and "foreground" or (m.muted and "mutedForeground" or "red")
        local props = { gap = 0, radius = radius, fill = style.backgrounds and "elevatedSurface" or nil,
            hoverOpacity = 0.9, block }
        if style.vertical then
            props.w, props.gap = size, 2
            if m.volume then
                props[#props + 1] = ui.text{ text = tostring(m.volume), style = "mono", size = 14 * scale,
                    weight = "semibold", color = hue }
                props[#props + 1] = ui.box{ w = 1, h = 3 }
            end
            return ui.column(props)
        end
        props.h = size
        if m.volume then
            props[#props + 1] = ui.box{ w = 8, h = 1 }
            props[#props + 1] = ui.text{ text = m.percent, style = "mono", size = 14 * scale, weight = "semibold",
                color = hue, reserve = ctx.format.percent(1) }
            props[#props + 1] = ui.box{ w = 9, h = 1 }
        end
        return ui.row(props)
    end,
    audioPanel = function(ctx, m)
        local header = { w = AUDIO_INNER, gap = 8,
            ui.symbol{ name = "speaker.wave.2.fill", size = 13, weight = "semibold", color = "accent" },
            ui.text{ text = omniwm.l10n("Sound"), size = 14, weight = "bold", color = "foreground" },
            ui.box{ grow = 1, h = 1 } }
        if m.volume then
            header[#header + 1] = audioMute(m.muted and "speaker.slash.fill" or "speaker.wave.2.fill", m.mute, m.muted)
        end
        local body = { w = AUDIO_WIDTH, pad = 16, gap = 8, center = false }
        if m.volume then
            body[#body + 1] = audioCard({
                ui.column{ w = AUDIO_CARD, gap = 8, center = false,
                    ui.box{ w = 1, h = 4 },
                    ui.row{ w = AUDIO_CARD, gap = 10,
                        audioWell(30, false, ui.symbol{ name = m.symbol, size = 13, weight = "semibold",
                            color = m.muted and "mutedForeground" or "secondaryForeground" }),
                        ui.column{ gap = 1, center = false,
                            ui.text{ text = caps(omniwm.l10n("Output")), size = 12, weight = "bold",
                                color = "mutedForeground" },
                            ui.text{ text = m.output and m.output.name or omniwm.l10n("Output"), size = 14,
                                weight = "semibold", color = "foreground", maxWidth = AUDIO_CARD - 90 } },
                        ui.box{ grow = 1, h = 1 },
                        ui.text{ text = m.percent, style = "mono", size = 14, weight = "bold",
                            color = m.muted and "mutedForeground" or "foreground", reserve = ctx.format.percent(1) } },
                    ui.slider{ value = m.level, w = AUDIO_CARD, h = 16,
                        color = m.muted and "mutedForeground" or "accent", onChange = m.set },
                    ui.box{ w = 1, h = 4 } } })
        else
            body[#body + 1] = audioCard({ ui.column{ w = AUDIO_CARD, gap = 8, center = false,
                ui.box{ w = 1, h = 4 },
                ui.text{ text = omniwm.l10n("Unavailable"), size = 13,
                    color = "secondaryForeground", w = AUDIO_CARD },
                ui.box{ w = 1, h = 4 } } })
        end
        if #m.outputs > 0 then
            local devices = { w = AUDIO_INNER, gap = 2, pad = 4, radius = 9, fill = "elevatedSurface", center = true }
            for _, output in ipairs(m.outputs) do
                devices[#devices + 1] = ui.row{ w = AUDIO_CARD, h = 44, gap = 10, radius = 7, hover = HOVER,
                    onClick = output.select,
                    audioWell(30, output.default, ui.symbol{ name = output.symbol, size = 13, weight = "semibold",
                        color = output.default and "accent" or "secondaryForeground" }),
                    ui.text{ text = output.name, size = 14, weight = output.default and "semibold" or "medium",
                        color = "foreground", maxWidth = AUDIO_CARD - 70 },
                    ui.box{ grow = 1, h = 1 },
                    ui.symbol{ name = "checkmark", size = 11, weight = "bold", color = "accent",
                        opacity = output.default and 1 or 0 } }
            end
            body[#body + 1] = ui.column(devices)
        end
        local apps = {}
        if m.permission then
            apps[#apps + 1] = ui.row{ w = AUDIO_CARD, h = 44, gap = 10, radius = 7, hover = HOVER,
                onClick = m.permission,
                audioWell(28, false, ui.symbol{ name = "lock.fill", size = 12, color = "warning" }),
                ui.text{ text = omniwm.l10n("Allow System Audio Recording to set app volumes"), size = 12,
                    weight = "medium", color = "foreground", maxWidth = AUDIO_CARD - 40, lines = 2 } }
        end
        for _, app in ipairs(m.apps) do
            apps[#apps + 1] = audioApp(app)
        end
        if #apps > 0 then
            body[#body + 1] = ui.box{ w = 1, h = 2 }
            body[#body + 1] = ui.row{ w = AUDIO_INNER, h = 18, ui.box{ w = 2, h = 1 },
                ui.text{ text = caps(omniwm.l10n("Applications")), size = 12, weight = "bold",
                    color = "mutedForeground" } }
            body[#body + 1] = audioCard(apps)
        end
        return frame(AUDIO_WIDTH, 44, ui.row(header), ui.column(body), true)
    end,
    omniwmButton = function(ctx, glyph, locked)
        local size = 32 * ctx.data.bar.style.height / 40
        glyph.size = math.floor(size * 0.6)
        return { w = size, h = size, radius = math.floor(size * 0.24),
            fill = locked and "warning/0.25" or "accent/0.18", hoverOpacity = 0.85 }, size
    end,
    systemStatsButton = function(ctx, glyph)
        local style = ctx.data.bar.style
        local size = 32 * style.height / 40
        glyph.size, glyph.weight = math.floor(size * 0.52), "semibold"
        glyph.color = style.textColor ~= nil and "foreground" or "secondaryForeground"
        return { w = size, h = size, radius = math.floor(size * 0.24),
            fill = style.backgrounds and "elevatedSurface" or nil, hover = "foreground/0.08" }
    end,
    systemStatsSection = function(_, kind, m, width)
        local inner = width - 20
        if kind == "header" then
            local host = m.host
            local row = { w = width, h = 52, gap = 10,
                ui.stack{ w = 30, h = 30, radius = 8, fill = "accent",
                    ui.symbol{ name = "applelogo", size = 16, weight = "semibold", color = "accentForeground" } },
                ui.column{ gap = 1, center = false, grow = 1,
                    ui.text{ text = host and host.name or omniwm.l10n("System"), size = 14, weight = "bold",
                        color = "foreground", maxWidth = 170 },
                    ui.text{ text = host and host.chip or omniwm.l10n("Loading…"), size = 12, weight = "medium",
                        color = "mutedForeground", maxWidth = 170 } } }
            if host then
                row[#row + 1] = ui.row{ h = 22, radius = 6, fill = "foreground/0.06", gap = 4,
                    ui.box{ w = 4, h = 1 },
                    ui.symbol{ name = "power", size = 9, weight = "bold", color = "green" },
                    ui.text{ text = host.uptime, style = "mono", size = 12, weight = "semibold",
                        color = "secondaryForeground" }, ui.box{ w = 5, h = 1 } }
            end
            return ui.row(row)
        elseif kind == "metrics" then
            local hues = { "blue", "purple", "green", "yellow" }
            local row = { w = width, gap = 0, pad = 4, radius = 9, fill = "elevatedSurface", center = false }
            for index, metric in ipairs(m.metrics) do
                row[#row + 1] = statsGauge(metric, hues[index], (width - 8) / 4)
            end
            return ui.row(row)
        elseif kind == "network" then
            local graph = { w = inner, h = 44 }
            if m.network.graph then
                local down, up = m.network.graph(inner, 44)
                for index, path in ipairs({ up, down }) do
                    if path then
                        graph[#graph + 1] = ui.path{ w = inner, h = 44, d = path,
                            border = index == 1 and "purple" or "blue", borderWidth = 1.5 }
                    end
                end
            else
                graph[#graph + 1] = ui.text{ text = omniwm.l10n("Collecting data…"), size = 11,
                    color = "mutedForeground" }
            end
            return statsCard(width, {
                ui.row{ w = inner, gap = 10, statsTile("network", "blue"),
                    ui.text{ text = omniwm.l10n("Network"), size = 13, weight = "semibold", color = "foreground" } },
                ui.stack(graph),
                statsDetail("arrow.down", "blue", omniwm.l10n("Download"), m.network.down, inner),
                statsDetail("arrow.up", "purple", omniwm.l10n("Upload"), m.network.up, inner),
                statsDetail("arrow.up.arrow.down", "accent", omniwm.l10n("Total"), m.network.total, inner) })
        elseif kind == "battery" then
            local battery = m.battery
            return statsCard(width, {
                statsDetail(battery.symbol, "green",
                    omniwm.l10n("Battery"), battery.percent, inner),
                ui.progress{ w = inner, h = 5, radius = 2.5, value = battery.level, fill = "foreground/0.08",
                    color = battery.low and "warning" or "green" },
                ui.text{ text = battery.status, size = 12, color = "secondaryForeground", maxWidth = inner } })
        elseif kind == "details" then
            local rows = {
                statsDetail("cpu", m.cpu.hot and "warning" or "blue", m.cpu.title, m.cpu.detail, inner, 2),
                statsDetail("cube", m.gpu.hot and "warning" or "purple", m.gpu.title, m.gpu.detail, inner, 2),
                statsDetail("memorychip", m.memory.pressure == "critical" and "red" or "green",
                    m.memory.title, m.memory.detail, inner, 2),
                statsDetail("internaldrive", "yellow", m.disk.title, m.disk.detail, inner, 2) }
            if m.host then
                rows[#rows + 1] = statsDetail("display", "blue", nil, table.concat(m.displays, "\n"), inner,
                    math.max(1, #m.displays))
                rows[#rows + 1] = statsDetail("laptopcomputer", "accent", m.host.model, m.host.os, inner, 2)
            end
            for index = #rows, 2, -1 do
                table.insert(rows, index, ui.box{ w = inner, h = 1, fill = "foreground/0.07" })
            end
            return statsCard(width, rows)
        end
        return nil
    end,
    systemStatsPanel = function(_, props)
        local header = table.remove(props, 1)
        local width = props.w
        props.center = false
        return frame(width, 52, header, ui.column(props))
    end,
    workspaceMetrics = function(_, style, m)
        return { item = 32 * m.scale, focusCue = supported(m) and not m.compact and style.backgrounds }
    end,
    workspaceMarker = function(_, workspace, style, m, occupied)
        if not supported(m) or (m.compact and not style.labels) then
            return nil
        end
        local radius = math.floor(m.item * 0.24)
        local fill = style.backgrounds and (filled(style, m, workspace.focused) and "accent"
            or (style.accents and "accent/0.24" or "foreground/0.07")) or nil
        local block = { w = m.vertical and m.item or (utf8.len(workspace.name) <= 2 and 28 * m.scale or nil),
            h = m.item, radius = radius, fill = fill }
        if occupied and not m.compact then
            block[#block + 1] = ui.box{ align = m.vertical and "bottom" or "trailing",
                w = m.vertical and m.item or radius, h = m.vertical and radius or m.item,
                fill = style.backgrounds and "elevatedSurface" or nil,
                ui.box{ w = m.vertical and m.item or radius, h = m.vertical and radius or m.item, fill = fill } }
        end
        block[#block + 1] = ui.row{
            ui.box{ w = 4 * m.scale, h = 1 },
            ui.text{ text = workspace.name, size = 14 * m.scale, weight = "bold",
                color = labelColor(style, m, workspace), maxWidth = m.vertical and m.item - 8 * m.scale or nil },
            ui.box{ w = 4 * m.scale, h = 1 } }
        return ui.stack(block)
    end,
    workspacePill = function(pill, workspace, style, m, occupied)
        if not supported(m) then
            return
        end
        pill.gap = 4 * m.scale
        pill.radius = math.floor(m.item * 0.24)
        if not (m.occupiedBackground and occupied and not workspace.focused) then
            pill.fill = style.backgrounds and "elevatedSurface" or nil
        end
        pill.hover = not workspace.focused and "accent/0.15" or nil
        if workspace.focused and not style.labels then
            pill.border = style.accents and m.indicator ~= "underline" and "accent"
                or (style.backgrounds and not style.accents and "secondaryForeground/0.5" or nil)
            pill.borderWidth = 1.5
        end
    end,
    windowIcon = function(icon)
        icon.radius = 5
    end,
    countBadge = function(text)
        return ui.row{ align = "bottomTrailing", dx = 1, dy = 1, h = 11, radius = 5.5,
            fill = "surface", border = "border", borderWidth = 1,
            ui.box{ w = 2.5, h = 1 },
            ui.text{ text = text, style = "mono", size = 8, weight = "bold", color = "foreground" },
            ui.box{ w = 2.5, h = 1 } }
    end,
    notificationBadge = function(item, mode, m)
        if mode == "dot" then
            return ui.box{ align = "topTrailing", w = 7, h = 7, radius = 3.5, fill = "badge",
                border = "elevatedSurface", borderWidth = 1 }
        end
        return ui.row{ align = "topTrailing", dx = 1, dy = -1, h = 11, radius = 5.5, fill = "badge",
            ui.box{ w = 2.5, h = 1 },
            ui.text{ text = item.badge, style = "mono", size = 8, weight = "bold", color = "background", maxWidth = m.slot },
            ui.box{ w = 2.5, h = 1 } }
    end,
    hiddenIndicator = function(item)
        local full = item.count > 0 and item.hidden == item.count
        return ui.stack{ align = "bottomLeading", dx = -1, dy = 1, w = 10, h = 10, radius = 5,
            fill = full and "badge" or "surface", border = full and nil or "badge", borderWidth = 1,
            ui.symbol{ name = full and "eye.slash.fill" or "eye.slash", size = 6, weight = "bold",
                color = full and "background" or "badge" } }
    end,
    floatingGroup = function(icons, style, m)
        local symbol = 12 * m.scale
        local group = { gap = m.scale, radius = 5 * m.scale,
            w = m.vertical and m.slot or nil, h = not m.vertical and m.slot or nil,
            fill = style.backgrounds and "foreground/0.06" or nil,
            spacer(m.vertical, 3 * m.scale),
            ui.symbol{ name = "rectangle.on.rectangle", size = symbol, w = symbol, h = symbol, weight = "semibold",
                color = style.textColor ~= nil and "foreground" or "mutedForeground" },
            spacer(m.vertical, m.scale) }
        for _, icon in ipairs(icons) do
            group[#group + 1] = icon
        end
        group[#group + 1] = spacer(m.vertical, m.scale)
        return line(m.vertical, group), 5 * m.scale + symbol + #icons * m.slot + (#icons + 3) * m.scale
    end,
    workspaceGroup = function(_, pills, _, _, m)
        if not supported(m) then
            return nil
        end
        pills.gap = 6 * m.scale
        return line(m.vertical, pills)
    end,
    scratchpadMetrics = function(_, _, m)
        return { item = 30 * m.scale, icon = 24 * m.scale, slot = 24 * m.scale,
            gap = 2, compactGap = 2, edge = 4, compactEdge = 4, spacing = 2 }
    end,
    scratchpadLabel = function(scratchpad, style, m, text, width)
        local active = (scratchpad.revealed or scratchpad.focused) and style.accents
        local hue = style.accentColor ~= nil and "accent" or "purple"
        local color = style.textColor ~= nil and "foreground" or active and hue
            or (scratchpad.visible and "foreground" or "secondaryForeground")
        local name = ui.text{ text = text, size = if width then math.min(14 * m.scale, width / 2) else 14 * m.scale,
            weight = "bold", color = color, maxWidth = width }
        if scratchpad.visible or active then
            return name
        end
        return line(m.vertical, { gap = 2, name,
            ui.symbol{ name = "eye.slash", size = 8, weight = "bold", color = "mutedForeground" } })
    end,
    scratchpadCount = function(text)
        return ui.row{ h = 14, radius = 7, fill = "foreground/0.08",
            ui.box{ w = 4, h = 1 },
            ui.text{ text = text, style = "mono", size = 9, weight = "bold", color = "secondaryForeground" },
            ui.box{ w = 4, h = 1 } }
    end,
    scratchpadIcon = function(_, glyph, member, scratchpad, style)
        glyph.opacity = member.focused and 1 or (style.inactive >= 0 and style.inactive
            or (scratchpad.visible and 0.9 or 0.6))
    end,
    scratchpadPill = function(node, scratchpad, style, m)
        local active = (scratchpad.revealed or scratchpad.focused) and style.accents
        local hue = style.accentColor ~= nil and "accent" or "purple"
        node.radius = math.floor(32 * m.scale * 0.24) - 1
        node.fill = (active and style.backgrounds) and (hue .. "/0.22") or nil
        node.hover = not active and (hue .. "/0.15") or nil
        node.border = scratchpad.focused and not style.accents and "foreground/0.4" or nil
        node.borderWidth = 1
        if not scratchpad.compact then
            table.insert(node, 3, spacer(m.vertical, 0))
        end
    end,
    scratchpadGroup = function(_, items, style, m)
        if #items == 0 then
            return ui.row{}
        end
        local size = 32 * m.scale
        local radius = math.floor(size * 0.24)
        local block = chip(size, m.vertical, "purple", { name = "tray.fill", size = math.floor(size * 0.5),
            weight = "semibold", color = "accentForeground" })
        items.gap = 2
        items.radius = radius
        items.fill = style.backgrounds and "elevatedSurface" or nil
        items.w = m.vertical and size or nil
        items.h = not m.vertical and size or nil
        table.insert(items, 1, spacer(m.vertical, 0))
        table.insert(items, 1, block)
        items[#items + 1] = spacer(m.vertical, 0)
        return line(m.vertical, items)
    end,
    pickerHeader = function(header, item)
        header[1].size = 13
        header[1].weight = "bold"
        header[1].maxWidth = 180
        table.insert(header, 1, ui.icon{ app = item.bundle, w = 18, h = 18, placeholder = "app.dashed" })
    end,
    pickerRow = function(row, window)
        row.pad = 10
        row.gap = 8
        row.radius = 9
        row[1].size = 14
        row[1].weight = window.focused and "semibold" or "medium"
        row[1].maxWidth -= 24
        table.insert(row, 1, ui.box{ w = 3, h = 16, radius = 1.5,
            fill = window.focused and "accent" or "foreground/0.12" })
    end,
    list = function(props)
        return dividedCard(props, nil, 276)
    end,
    hiddenMenuRow = function(row, item, kind)
        if kind == "separator" then
            row[1].fill = "foreground/0.08"
        elseif kind == "item" then
            row[1].size, row[1].weight, row[1].color = 12, "bold", "accent"
            row[2].size, row[2].weight = 12, "medium"
            row[2].color = item.enabled and "foreground" or "mutedForeground"
            row[3].style, row[3].size, row[3].weight, row[3].color = "mono", 11, "medium", "mutedForeground"
            if item.submenu then
                row[4].weight, row[4].color = "bold", "mutedForeground"
            end
        elseif kind == "back" then
            row[1].weight, row[1].color = "bold", "accent"
            row[2].size, row[2].weight, row[2].color = 12, "semibold", "accent"
        elseif kind == "title" then
            local label = row[1]
            label.text = caps(label.text)
            label.size, label.weight, label.color = 10, "bold", "mutedForeground"
        elseif kind == "empty" then
            row[1].size, row[1].color = 12, "mutedForeground"
        elseif kind == "unavailable" then
            row.size, row.color = 12, "mutedForeground"
        end
    end,
    hiddenMenuPanel = function(_, rows)
        rows.radius, rows.material, rows.fill = 12, "clear", "surface"
        rows.border, rows.borderWidth, rows.center = "border", 1, false
        return ui.column(rows)
    end,
    panel = titledPanel,
})
