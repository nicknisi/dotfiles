-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local weather = {}
local HOURS = 12
local COMPACT_HOURS = 8
local COMPACT_DAYS = 5
local CONDITIONS = {
    Clear = omniwm.l10n("Clear"),
    ["Partly cloudy"] = omniwm.l10n("Partly cloudy"),
    Overcast = omniwm.l10n("Overcast"),
    Fog = omniwm.l10n("Fog"),
    Drizzle = omniwm.l10n("Drizzle"),
    ["Freezing rain"] = omniwm.l10n("Freezing rain"),
    Rain = omniwm.l10n("Rain"),
    Snow = omniwm.l10n("Snow"),
    Thunderstorms = omniwm.l10n("Thunderstorms"),
    Unknown = omniwm.l10n("Unknown"),
}

local function degrees(value: number?): string
    return if value then string.format("%d°", math.round(value)) else "–"
end

local function temperature(ctx, value: number?, unit: string): string
    return if value then ctx.format.number(math.round(value), 0) .. unit else "--"
end

local function label(condition: string?): string?
    return condition and (CONDITIONS[condition] or condition)
end

function weather.accessMessage(ctx)
    local access = ctx.select("weather", "access")
    return if access == "off" then omniwm.l10n("Turned off in Settings")
        elseif access == "blocked" then omniwm.l10n("Blocked by your organization") else nil
end

function weather.state(ctx, withUnit: boolean?)
    local symbol = ctx.select("weather", "symbol")
    if not symbol then
        return nil
    end
    local condition = ctx.select("weather", "condition")
    local value = ctx.select("weather", "temp")
    local state = { symbol = symbol, temp = degrees(value), condition = label(condition),
        kind = condition, code = ctx.select("weather", "code"), isDay = ctx.select("weather", "day") }
    if withUnit then
        state.temperature = temperature(ctx, value, ctx.select("weather", "unit"))
    end
    return state
end

function weather.model(ctx, compact: boolean?)
    local data = ctx.data.weather
    if not data or weather.accessMessage(ctx) then
        return nil
    end
    local m = { temp = degrees(data.temp), temperature = temperature(ctx, data.temp, data.unit),
        feelsValue = temperature(ctx, data.feels, data.unit),
        symbol = data.symbol, condition = label(data.condition), kind = data.condition,
        place = data.place, stale = if data.status == "stale" then omniwm.l10n("Last update failed") else nil,
        reading = data,
        attribution = omniwm.l10n("Weather by %@", "Open-Meteo.com"), hours = {}, days = {} }
    if data.feels then
        m.feels = omniwm.l10n("Feels like %@", degrees(data.feels))
    end
    if data.high and data.low then
        m.high = omniwm.l10n("High %@", degrees(data.high))
        m.low = omniwm.l10n("Low %@", degrees(data.low))
    end
    if data.rain then
        m.rain = omniwm.l10n("%lld%% chance of rain", data.rain)
    end
    if data.wind then
        m.windValue = string.format("%s %s", ctx.format.number(math.round(data.wind), 0),
            if data.unit == "°F" then "mph" else "km/h")
        m.wind = omniwm.l10n("Wind %@", m.windValue)
    end
    local limit = if compact then COMPACT_HOURS else tonumber((ctx.data.settings or {}).forecastHours) or HOURS
    m.forecastHours = limit
    for index, hour in data.hours do
        if index > limit then
            break
        end
        m.hours[index] = { label = hour.label, symbol = hour.symbol, temp = degrees(hour.temp),
            condition = label(hour.condition), kind = hour.condition, reading = hour }
    end
    local floor, ceiling = math.huge, -math.huge
    for _, day in data.days do
        floor = math.min(floor, day.low)
        ceiling = math.max(ceiling, day.high)
    end
    local span = math.max(ceiling - floor, 1)
    for index, day in data.days do
        if compact and index > COMPACT_DAYS then
            break
        end
        m.days[index] = { label = day.label, symbol = day.symbol, condition = label(day.condition), kind = day.condition,
            rain = if day.rain and day.rain > 0 then ctx.format.percent(day.rain / 100) else nil,
            low = degrees(day.low), high = degrees(day.high),
            from = (day.low - floor) / span, to = (day.high - floor) / span, reading = day }
    end
    return m
end

local function line(symbol: string, text: string, width: number)
    return ui.row{ w = width - 24, gap = 8,
        look.glyph{ name = symbol, w = 16, h = 16, color = "secondaryForeground" },
        look.text{ text = text, size = 13, maxWidth = width - 48 } }
end

local function full(m, width: number)
    local header = { gap = 3, center = false,
        look.text{ text = m.temp, size = 28, weight = "medium" },
        look.text{ text = m.condition, size = 13, maxWidth = width - 82 } }
    if m.place then
        header[#header + 1] = look.text{ text = m.place, size = 11, color = "secondaryForeground", maxWidth = width - 82 }
    end
    local current = { w = width,
        ui.row{ w = width - 24, gap = 16,
            look.glyph{ name = m.symbol, w = 42, h = 42, color = "secondaryForeground" }, ui.column(header) } }
    if m.feels then
        current[#current + 1] = line("thermometer.medium", m.feels, width)
    end
    if m.high then
        current[#current + 1] = line("arrow.up.arrow.down", m.high .. "  " .. m.low, width)
    end
    if m.rain then
        current[#current + 1] = line("umbrella", m.rain, width)
    end
    if m.wind then
        current[#current + 1] = line("wind", m.wind, width)
    end
    local rows = { w = width, gap = 12, center = false, look.group(current) }
    if #m.hours > 0 then
        local forecast = { w = width, gap = 12 }
        local strip = { gap = 4 }
        for _, hour in m.hours do
            strip[#strip + 1] = ui.column{ w = 46, gap = 6, center = true, help = hour.condition,
                look.text{ text = hour.label, size = 11, color = "secondaryForeground", maxWidth = 46 },
                look.glyph{ name = hour.symbol, w = 18, h = 18 },
                look.text{ text = hour.temp, size = 13 } }
            if #strip == 6 then
                forecast[#forecast + 1] = ui.row(strip)
                strip = { gap = 4 }
            end
        end
        if #strip > 0 then
            forecast[#forecast + 1] = ui.row(strip)
        end
        rows[#rows + 1] = look.group(forecast)
    end
    if #m.days > 0 then
        local forecast = { w = width, gap = 12 }
        for _, day in m.days do
            forecast[#forecast + 1] = ui.row{ w = width - 24, gap = 8,
                look.text{ text = day.label, size = 13, w = 110, maxWidth = 110 },
                look.glyph{ name = day.symbol, w = 18, h = 18, help = day.condition },
                look.text{ text = day.rain or "", size = 11, color = "accent", w = 46, maxWidth = 46 },
                look.text{ text = day.low, size = 13, color = "secondaryForeground", w = 40 },
                look.text{ text = day.high, size = 13, w = 40 } }
        end
        rows[#rows + 1] = look.group(forecast)
    end
    if m.stale then
        rows[#rows + 1] = ui.row{ w = width, gap = 8,
            look.glyph{ name = "exclamationmark.triangle", w = 16, h = 16, color = "warning" },
            look.text{ text = m.stale, size = 13, color = "secondaryForeground" } }
    end
    rows[#rows + 1] = look.text{ text = m.attribution, size = 11, color = "secondaryForeground" }
    return ui.column(rows)
end

local function compact(m, width: number)
    local inner = width - 24
    local now = { gap = 1, center = false,
        look.text{ text = m.temp, size = 30, weight = "semibold" },
        look.text{ text = m.condition, size = 13, maxWidth = inner - 60 } }
    if m.place then
        now[#now + 1] = look.text{ text = m.place, size = 11, color = "secondaryForeground", maxWidth = inner - 60 }
    end
    local facts = { gap = 3, center = false }
    if m.high then
        facts[#facts + 1] = look.text{ text = m.high .. "  " .. m.low, size = 11 }
    end
    if m.feels then
        facts[#facts + 1] = look.text{ text = m.feels, size = 11, color = "secondaryForeground" }
    end
    if m.rain then
        facts[#facts + 1] = look.text{ text = m.rain, size = 11, color = "secondaryForeground" }
    end
    local hours = { gap = 0 }
    for _, hour in m.hours do
        hours[#hours + 1] = ui.column{ w = inner / COMPACT_HOURS, gap = 4,
            look.text{ text = hour.label, size = 11, color = "secondaryForeground", maxWidth = inner / COMPACT_HOURS },
            look.glyph{ name = hour.symbol, w = 16, h = 16 },
            look.text{ text = hour.temp, size = 11 } }
    end
    local track = inner - 192
    local days = { w = width, gap = 5 }
    for _, day in m.days do
        days[#days + 1] = ui.row{ w = inner, gap = 8,
            look.text{ text = day.label, size = 13, w = 50, maxWidth = 50 },
            look.glyph{ name = day.symbol, w = 16, h = 16 },
            look.text{ text = day.rain or "", size = 11, color = "accent", w = 30 },
            look.text{ text = day.low, size = 12, color = "secondaryForeground", w = 28 },
            ui.stack{ w = track, h = 4, radius = 2, fill = "foreground/0.12",
                ui.box{ align = "leading", dx = day.from * track, w = math.max(4, (day.to - day.from) * track), h = 4,
                    radius = 2, fill = "accent" } },
            look.text{ text = day.high, size = 12, w = 28 } }
    end
    return ui.column{ gap = 8,
        look.group{ w = width,
            ui.row{ w = inner, gap = 12, look.glyph{ name = m.symbol, w = 40, h = 40 }, ui.column(now) },
            ui.column(facts) },
        look.group{ w = width, ui.row(hours) },
        look.group(days) }
end

function weather.content(ctx, isCompact: boolean?, width: number?, m)
    width = width or look.width
    m = m or weather.model(ctx, isCompact)
    if not m then
        return actions.notice(weather.accessMessage(ctx) or omniwm.l10n("Unavailable"), width)
    end
    return if isCompact then compact(m, width) else full(m, width)
end

function weather.popout(ctx)
    local message = weather.accessMessage(ctx)
    if message then
        return look.panel(ctx, { w = look.width + 28,
            look.heading(omniwm.l10n("Weather"), look.width), actions.notice(message, look.width) })
    end
    local m = weather.model(ctx)
    return look.weatherPanel and look.weatherPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28,
            look.heading(omniwm.l10n("Weather"), look.width), weather.content(ctx, false, nil, m) })
end

return table.freeze(weather)
