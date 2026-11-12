-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local battery = {}

local function tint(level: number, charging: boolean): string
    if charging then
        return "success"
    end
    if level <= 10 then
        return "error"
    end
    return if level <= 20 then "warning" else "foreground"
end

local function duration(minutes: number): string
    return omniwm.l10n("%lldh %lldm", minutes // 60, minutes % 60)
end

function battery.state(ctx)
    local level = ctx.data.battery
    if not level then
        return nil
    end
    local charging = ctx.data.charging == true
    return { level = level, charging = charging, low = level <= 20 and not charging, tint = tint(level, charging),
        symbol = look.batterySymbol(level, charging), text = tostring(level), percent = ctx.format.percent(level / 100),
        reserve = ctx.format.percent(1), mode = (ctx.data.settings or {}).percent or "beside" }
end

function battery.model(ctx)
    local m = battery.state(ctx)
    if not m then
        return nil
    end
    local power = ctx.data.power or {}
    m.status = if power.charged then omniwm.l10n("Fully charged")
        elseif m.charging then omniwm.l10n("Charging")
        elseif power.source == "ac" then omniwm.l10n("Not charging")
        else omniwm.l10n("On battery")
    m.details = {}
    if power.source then
        m.details[#m.details + 1] = { label = omniwm.l10n("Power Source"),
            value = if power.source == "ac" then omniwm.l10n("Power Adapter") else omniwm.l10n("Battery") }
    end
    if not m.charging and power.remaining then
        m.details[#m.details + 1] = { label = omniwm.l10n("Time Remaining"), value = duration(power.remaining) }
    elseif m.charging and power.full then
        m.details[#m.details + 1] = { label = omniwm.l10n("Time to Full"), value = duration(power.full) }
    end
    if power.lowPower ~= nil then
        m.details[#m.details + 1] = { label = omniwm.l10n("Low Power Mode"),
            value = if power.lowPower then omniwm.l10n("On") else omniwm.l10n("Off") }
    end
    m.settings = "battery settings"
    return m
end

function battery.cell(state, w: number, h: number, inside: string?)
    local body = { w = w, h = h, radius = h * 0.3, border = "foreground/0.45", borderWidth = 1,
        ui.box{ align = "leading", dx = 2, w = math.max(1.5, (w - 4) * state.level / 100), h = h - 4,
            radius = (h - 4) * 0.3, fill = if inside then state.tint .. "/0.22" else state.tint } }
    if inside then
        body[#body + 1] = look.text{ text = inside, size = h * 0.72, weight = "semibold" }
    elseif state.charging then
        body[#body + 1] = look.glyph{ name = "bolt.fill", size = h * 0.78, color = "foreground" }
    end
    return ui.row{ gap = 1,
        ui.stack(body),
        ui.box{ w = math.max(1.5, h * 0.14), h = h * 0.4, radius = h * 0.07, fill = "foreground/0.45" } }
end

function battery.content(ctx, width: number?, m)
    width = width or look.width
    m = m or battery.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Unavailable"), width)
    end
    local rows = { w = width, gap = 12, center = false,
        look.group{ w = width,
            ui.row{ w = width - 24, gap = 16,
                battery.cell(m, 58, 28),
                ui.column{ gap = 3, center = false,
                    look.text{ text = m.percent, size = 28, weight = "medium" },
                    look.text{ text = m.status, size = 13, color = "secondaryForeground", maxWidth = width - 108 } } } } }
    if #m.details > 0 then
        local details = { w = width }
        for _, detail in m.details do
            details[#details + 1] = ui.row{ w = width - 24, gap = 8,
                look.text{ text = detail.label, size = 13, color = "secondaryForeground", grow = 1, maxWidth = 170 },
                look.text{ text = detail.value, size = 13, weight = "medium", maxWidth = 118 } }
        end
        rows[#rows + 1] = look.group(details)
    end
    rows[#rows + 1] = actions.row("gearshape", omniwm.l10n("Battery Settings…"), m.settings, width)
    return ui.column(rows)
end

function battery.popout(ctx)
    local m = battery.model(ctx)
    return look.batteryPanel and look.batteryPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28,
            look.heading(omniwm.l10n("Battery"), look.width), battery.content(ctx, nil, m) })
end

return table.freeze(battery)
