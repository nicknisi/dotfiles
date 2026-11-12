-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local wifi = { settings = "wifi settings" }
local SPREAD = math.rad(45)
local BANDS = { { 0, 2.8 }, { 5.2, 7.8 }, { 10, 12.6 }, { 14.8, 17.4 } }

local function bars(rssi: number?): number
    if not rssi then
        return 0
    end
    if rssi >= -60 then
        return 3
    end
    if rssi >= -70 then
        return 2
    end
    return if rssi >= -80 then 1 else 0
end

local function quality(rssi: number): string
    if rssi >= -60 then
        return omniwm.l10n("Excellent")
    end
    if rssi >= -70 then
        return omniwm.l10n("Good")
    end
    return if rssi >= -80 then omniwm.l10n("Fair") else omniwm.l10n("Weak")
end

local function sector(inner: number, outer: number): string
    local x, y = math.sin(SPREAD), math.cos(SPREAD)
    return string.format("M%.2f %.2f A%.2f %.2f 0 0 1 %.2f %.2f L%.2f %.2f A%.2f %.2f 0 0 0 %.2f %.2f Z",
        12 - outer * x, 20.5 - outer * y, outer, outer, 12 + outer * x, 20.5 - outer * y,
        12 + inner * x, 20.5 - inner * y, inner, inner, 12 - inner * x, 20.5 - inner * y)
end

function wifi.fan(level: number, size: number, color: string, dim: string?)
    local stack = { w = size, h = size }
    for index, band in BANDS do
        stack[#stack + 1] = ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = sector(band[1], band[2]),
            fill = if index - 1 <= level then color else dim or "foreground/0.2" }
    end
    return ui.stack(stack)
end

function wifi.state(ctx)
    local data = ctx.data.wifi
    if not data then
        return nil
    end
    return { power = data.power, connected = data.connected, ssid = data.ssid, rssi = data.rssi,
        level = if data.connected then bars(data.rssi) else -1,
        help = if not data.power then omniwm.l10n("Wi-Fi: Off")
            elseif data.ssid then data.ssid
            elseif data.connected then omniwm.l10n("Wi-Fi: Connected")
            else omniwm.l10n("Wi-Fi: Not Connected") }
end

function wifi.glyph(state, size: number)
    if not state.power then
        return look.glyph{ name = "wifi.slash", size = size, color = "secondaryForeground" }
    end
    return wifi.fan(state.level, size, "foreground")
end

function wifi.model(ctx)
    local m = wifi.state(ctx)
    if not m then
        return nil
    end
    local data = ctx.data.wifi
    m.status = if data.power then omniwm.l10n("On") else omniwm.l10n("Off")
    m.connectionStatus = if not data.power then omniwm.l10n("Off")
        elseif data.connected then omniwm.l10n("Connected") else omniwm.l10n("Not Connected")
    m.name = data.ssid or omniwm.l10n("Network name hidden")
    m.details = {}
    if data.power and data.connected then
        if data.rssi then
            m.details[#m.details + 1] = { symbol = "cellularbars", label = omniwm.l10n("Signal"),
                value = string.format("%d dBm · %s", data.rssi, quality(data.rssi)) }
        end
        if data.band then
            m.details[#m.details + 1] = { symbol = "antenna.radiowaves.left.and.right", label = omniwm.l10n("Band"),
                value = if data.channel then string.format("%s · %d", data.band, data.channel) else data.band }
        end
        if data.security then
            m.details[#m.details + 1] = { symbol = "lock", label = omniwm.l10n("Security"), value = data.security }
        end
    end
    m.actions = {}
    if data.power and data.location ~= "authorized" then
        m.actions[#m.actions + 1] = { symbol = "location.fill",
            text = omniwm.l10n("Allow Location Access to show the network name"), command = "wifi authorize",
            wrap = true, prompt = true }
    end
    m.actions[#m.actions + 1] = { symbol = "gearshape", text = omniwm.l10n("Wi-Fi Settings…"), command = wifi.settings,
        wrap = true }
    return m
end

local function detail(entry, width: number)
    return ui.row{ w = width - 24, gap = 8,
        look.glyph{ name = entry.symbol, w = 16, h = 16, color = "secondaryForeground" },
        look.text{ text = entry.label, size = 13, color = "secondaryForeground", grow = 1, maxWidth = 88 },
        look.text{ text = entry.value, size = 12, maxWidth = width - 152 } }
end

function wifi.content(ctx, width: number?, m)
    width = width or look.width
    m = m or wifi.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Unavailable"), width)
    end
    local rows = { w = width, gap = 12, center = false,
        ui.row{ w = width,
            look.text{ text = omniwm.l10n("Wi-Fi"), size = 14, weight = "semibold", grow = 1 },
            look.text{ text = m.status, size = 13, color = "secondaryForeground" } } }
    if m.power and m.connected then
        local card = { w = width,
            ui.row{ w = width - 24, gap = 12,
                ui.stack{ w = 36, h = 36, radius = look.radius(18), fill = "accent", wifi.fan(m.level, 20, "accentForeground") },
                ui.column{ gap = 3, center = false,
                    look.text{ text = m.name, size = 13, weight = "medium", maxWidth = width - 72 },
                    look.text{ text = omniwm.l10n("Connected"), size = 11, color = "secondaryForeground" } } } }
        for _, entry in m.details do
            card[#card + 1] = detail(entry, width)
        end
        rows[#rows + 1] = look.group(card)
    elseif m.power then
        rows[#rows + 1] = look.group{ w = width,
            look.text{ text = omniwm.l10n("Not Connected"), size = 13, color = "secondaryForeground" } }
    end
    for _, action in m.actions do
        rows[#rows + 1] = actions.row(action.symbol, action.text, action.command, width, action.wrap)
    end
    return ui.column(rows)
end

function wifi.popout(ctx)
    local m = wifi.model(ctx)
    return look.wifiPanel and look.wifiPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28, wifi.content(ctx, nil, m) })
end

return table.freeze(wifi)
