-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local bluetooth = {}
local RUNE = "M7 7.5 L17 16.5 L12 21 L12 3 L17 7.5 L7 16.5"
local KINDS = {
    headphones = "headphones",
    keyboard = "keyboard",
    mouse = "magicmouse",
    gamepad = "gamecontroller",
    phone = "iphone",
    computer = "laptopcomputer",
}

local function lowBattery(level: number): boolean
    return level <= 20
end

function bluetooth.rune(size: number, color: string)
    return ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = RUNE, border = color, borderWidth = 2.2 }
end

function bluetooth.cell(level: number)
    local color = if lowBattery(level) then "error" else "foreground/0.75"
    return ui.row{ gap = 1,
        ui.stack{ w = 20, h = 10, radius = 3, border = "foreground/0.45", borderWidth = 1,
            ui.box{ align = "leading", dx = 2, w = math.max(1.5, 16 * level / 100), h = 6, radius = 1.5, fill = color } },
        ui.box{ w = 1.5, h = 4, radius = 0.75, fill = "foreground/0.45" } }
end

function bluetooth.state(ctx)
    local data = ctx.data.bluetooth
    if not data then
        return nil
    end
    local connected = 0
    for _, entry in data.devices or {} do
        if entry.connected then
            connected += 1
        end
    end
    return { power = data.power, granted = data.access == "granted", connected = connected,
        help = if data.access ~= "granted" then omniwm.l10n("Bluetooth")
            elseif not data.power then omniwm.l10n("Bluetooth: Off")
            else omniwm.l10n("Bluetooth: %lld connected", connected) }
end

function bluetooth.glyph(state, size: number)
    local glyph = { w = size, h = size,
        bluetooth.rune(size, if state.power then "foreground" else "secondaryForeground") }
    if state.power and state.connected > 0 then
        glyph[#glyph + 1] = ui.box{ align = "bottomTrailing", w = size / 4, h = size / 4, radius = size / 8,
            fill = "accent" }
    end
    return ui.stack(glyph)
end

function bluetooth.model(ctx)
    local m = bluetooth.state(ctx)
    if not m then
        return nil
    end
    m.status = if not m.granted then nil elseif m.power then omniwm.l10n("On") else omniwm.l10n("Off")
    m.devices = {}
    if m.power then
        for _, entry in ctx.data.bluetooth.devices or {} do
            local battery = if entry.connected then entry.battery else nil
            m.devices[#m.devices + 1] = { id = entry.id, kind = entry.kind, name = entry.name, connected = entry.connected,
                symbol = KINDS[entry.kind] or "dot.radiowaves.left.and.right",
                status = if entry.connected then omniwm.l10n("Connected") else omniwm.l10n("Not Connected"),
                battery = battery, batteryText = battery and ctx.format.percent(battery / 100),
                lowBattery = battery ~= nil and lowBattery(battery) }
        end
    end
    m.actions = {}
    if not m.granted then
        m.actions[#m.actions + 1] = { symbol = "lock.fill", text = omniwm.l10n("Allow Bluetooth access to list devices"),
            command = "bluetooth authorize", wrap = true, prompt = true }
    end
    m.actions[#m.actions + 1] = { symbol = "gearshape", text = omniwm.l10n("Bluetooth Settings…"),
        command = "bluetooth settings" }
    return m
end

local function device(entry, width: number)
    local row = { w = width - 24, gap = 8, pad = 4,
        ui.stack{ w = 32, h = 32, radius = look.radius(16), fill = if entry.connected then "accent" else "foreground/0.08",
            look.glyph{ name = entry.symbol, w = 16, h = 16,
                color = if entry.connected then "accentForeground" else "secondaryForeground" } },
        ui.column{ gap = 3, center = false, grow = 1,
            look.text{ text = entry.name, size = 13, weight = if entry.connected then "medium" else nil, maxWidth = 156 },
            look.text{ text = entry.status, size = 11, color = "secondaryForeground", maxWidth = 156 } } }
    if entry.battery then
        row[#row + 1] = look.text{ text = entry.batteryText, size = 11, color = "secondaryForeground", maxWidth = 42 }
        row[#row + 1] = bluetooth.cell(entry.battery)
    end
    return ui.row(row)
end

function bluetooth.content(ctx, width: number?, m)
    width = width or look.width
    m = m or bluetooth.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Unavailable"), width)
    end
    local header = { w = width, look.text{ text = omniwm.l10n("Bluetooth"), size = 14, weight = "semibold", grow = 1 } }
    if m.status then
        header[#header + 1] = look.text{ text = m.status, size = 13, color = "secondaryForeground" }
    end
    local rows = { w = width, gap = 12, center = false, ui.row(header) }
    if m.power then
        local devices = { w = width,
            look.text{ text = omniwm.l10n("Devices"), size = 11, weight = "medium", color = "secondaryForeground" } }
        for _, entry in m.devices do
            devices[#devices + 1] = device(entry, width)
        end
        rows[#rows + 1] = look.group(devices)
    end
    for _, action in m.actions do
        rows[#rows + 1] = actions.row(action.symbol, action.text, action.command, width, action.wrap)
    end
    return ui.column(rows)
end

function bluetooth.popout(ctx)
    local m = bluetooth.model(ctx)
    return look.bluetoothPanel and look.bluetoothPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28, bluetooth.content(ctx, nil, m) })
end

return table.freeze(bluetooth)
