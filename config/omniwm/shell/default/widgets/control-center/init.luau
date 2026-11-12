-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local audio = require("../lib/audio")
local media = require("../lib/media")
local calendar = require("../lib/calendar")
local weather = require("../lib/weather")
local wifi = require("../lib/wifi")
local bluetooth = require("../lib/bluetooth")
local battery = require("../lib/battery")
local stats = require("../lib/stats")

local CONTENT = look.panelWidth("control-center")
local INNER = CONTENT - 24
local TABS = {
    { id = "overview", symbol = "square.grid.2x2", label = omniwm.l10n("Control Center") },
    { id = "audio", symbol = "speaker.wave.2.fill", label = omniwm.l10n("Audio") },
    { id = "media", symbol = "music.note", label = omniwm.l10n("Media") },
    { id = "calendar", symbol = "calendar", label = omniwm.l10n("Calendar") },
    { id = "weather", symbol = "cloud.sun.fill", label = omniwm.l10n("Weather") },
    { id = "system", symbol = "gauge.with.needle", label = omniwm.l10n("System") },
}
local GAUGES = {
    { key = "cpu", label = omniwm.l10n("CPU") },
    { key = "gpu", label = omniwm.l10n("GPU") },
    { key = "memory", label = omniwm.l10n("Memory") },
    { key = "disk", label = omniwm.l10n("Disk") },
}

local function card(props)
    props.w = CONTENT
    return look.group(props)
end

local function gauge(label: string, row)
    local width = (INNER - 36) / 4
    return ui.column{ w = width, gap = 6,
        look.text{ text = if row then row.text else "—", size = 17, weight = "medium" },
        ui.progress{ value = (row and row.value or 0) / 100, w = width, h = 4, radius = 2, fill = "foreground/0.08",
            color = if row and row.hot then "warning" else "accent" },
        look.text{ text = label, size = 11, color = "secondaryForeground" } }
end

local function systemTab(ctx)
    local rows = {}
    for _, row in stats.model(ctx).rows do
        rows[row.key] = row
    end
    local gauges = { w = INNER, gap = 12 }
    for _, entry in GAUGES do
        gauges[#gauges + 1] = gauge(entry.label, rows[entry.key])
    end
    local sections = { gap = 8, card{ ui.row(gauges) } }
    local facts = { gap = 6 }
    local system = ctx.data.system
    if system then
        facts[#facts + 1] = ui.row{ w = INNER, gap = 10,
            look.glyph{ name = "applelogo", w = 18, h = 18 },
            ui.column{ gap = 1, center = false,
                look.text{ text = system.host.name, size = 13, weight = "semibold", maxWidth = INNER - 30 },
                look.text{ text = system.host.chip .. " · " .. system.host.os, size = 11,
                    color = "secondaryForeground", maxWidth = INNER - 30 } } }
    end
    if rows.down then
        facts[#facts + 1] = ui.row{ w = INNER, gap = 6,
            look.glyph{ name = "arrow.down", w = 12, h = 12, color = "secondaryForeground" },
            look.text{ text = rows.down.text, style = "mono", size = 11, reserve = "000.0 MB/s" },
            ui.box{ grow = 1 },
            look.glyph{ name = "arrow.up", w = 12, h = 12, color = "secondaryForeground" },
            look.text{ text = rows.up.text, style = "mono", size = 11, reserve = "000.0 MB/s" } }
    end
    if #facts > 0 then
        sections[#sections + 1] = card(facts)
    end
    return ui.column(sections)
end

local function connection(name: string, text: string, glyph, command: string)
    local width = (CONTENT - 12) / 2
    return look.group{ w = width, gap = 6, hover = look.hover, onClick = command,
        ui.row{ gap = 6,
            glyph,
            look.text{ text = name, size = 13, weight = "semibold" } },
        look.text{ text = text, size = 11, color = "secondaryForeground", maxWidth = width - 24 } }
end

local function overview(ctx)
    local network = wifi.model(ctx)
    local radio = bluetooth.state(ctx)
    local wireless = if not network then omniwm.l10n("Unavailable")
        else network.power and network.ssid or network.connectionStatus
    local devices = if not radio then omniwm.l10n("Unavailable")
        elseif not radio.granted then omniwm.l10n("Allow Access")
        elseif not radio.power then omniwm.l10n("Off")
        elseif radio.connected > 0 then tostring(radio.connected) .. " · " .. omniwm.l10n("Connected")
        else omniwm.l10n("On")
    local rows = { w = CONTENT, gap = 12, center = false,
        ui.row{ gap = 12,
            connection(omniwm.l10n("Wi-Fi"), wireless,
                look.glyph{ name = if network and network.power then "wifi" else "wifi.slash", w = 16, h = 16,
                    color = if network and network.connected then "accent" else "secondaryForeground" }, wifi.settings),
            connection(omniwm.l10n("Bluetooth"), devices,
                bluetooth.rune(16, if radio and radio.power then "accent" else "secondaryForeground"),
                if radio and not radio.granted then "bluetooth authorize" else "bluetooth settings") },
        audio.level(ctx, CONTENT),
        media.content(ctx, true, CONTENT) }
    local charge = battery.model(ctx)
    if charge then
        rows[#rows + 1] = card{ hover = look.hover, onClick = charge.settings,
            ui.row{ w = INNER, gap = 8,
                look.glyph{ name = charge.symbol, w = 22, h = 16 },
                look.text{ text = omniwm.l10n("Battery"), size = 13, grow = 1 },
                look.text{ text = charge.percent, size = 13 },
                look.glyph{ name = "chevron.right", w = 10, h = 10, color = "secondaryForeground" } },
            look.text{ text = charge.status, size = 11, color = "secondaryForeground" } }
    end
    return ui.column(rows)
end

local SECTIONS = {
    overview = overview,
    audio = function(ctx)
        return audio.content(ctx, CONTENT)
    end,
    media = function(ctx)
        return media.content(ctx, false, CONTENT)
    end,
    calendar = function(ctx)
        return calendar.content(ctx, CONTENT)
    end,
    weather = function(ctx)
        return weather.content(ctx, true, CONTENT)
    end,
    system = systemTab,
}

local function selected(ctx): string
    local tab = ctx.state.tab or (ctx.data.settings or {}).tab
    return if SECTIONS[tab] then tab else "overview"
end

function render(ctx: Context)
    local state = { symbol = "switch.2" }
    local behaviour = { onClick = ui.popout, help = omniwm.l10n("Control Center") }
    local button = look.controlCenterBar and look.controlCenterBar(ctx, state)
    if not button then
        local props = table.clone(behaviour)
        props[1] = look.glyph{ name = state.symbol, size = 14 * look.scale(ctx) }
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx: Context)
    local current = selected(ctx)
    local tabs = { w = CONTENT, gap = 4 }
    local title = omniwm.l10n("Control Center")
    for _, tab in TABS do
        local active = tab.id == current
        if active then
            title = tab.label
        end
        tabs[#tabs + 1] = look.button(tab.symbol, function(state)
            state.state.tab = tab.id
        end, { w = (CONTENT - 20) / 6, h = 30, help = tab.label, fill = if active then "foreground/0.10" else nil })
    end
    local props = { w = CONTENT + 28, look.heading(title), ui.row(tabs), SECTIONS[current](ctx) }
    return look.controlCenterPanel and look.controlCenterPanel(ctx, props) or look.panel(ctx, props)
end
