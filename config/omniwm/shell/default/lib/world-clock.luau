-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local worldClock = {}
local ZONES = {
    { label = "London", zone = "Europe/London" },
    { label = "Tokyo", zone = "Asia/Tokyo" },
}

type Moment = { time: string, day: number, hour: number, minutes: number }

local function moment(ctx: Context, zone: string?): Moment?
    local now = ctx.data.seconds
    local offset = ctx.format.offset(now, zone)
    if not offset then
        return nil
    end
    local parts = os.date("!*t", math.floor(now + offset))
    return { time = ctx.format.date(now, "jmm", zone) or "", minutes = offset // 60, hour = parts.hour,
        day = parts.year * 10000 + parts.month * 100 + parts.day }
end

local function relative(here: Moment, there: Moment): string
    local day = if there.day > here.day then omniwm.l10n("Tomorrow")
        elseif there.day < here.day then omniwm.l10n("Yesterday")
        else omniwm.l10n("Today")
    local minutes = there.minutes - here.minutes
    if minutes == 0 then
        return day
    end
    local sign = if minutes > 0 then "+" else "−"
    local whole = math.abs(minutes)
    local shift = if whole % 60 == 0 then string.format("%s%d h", sign, whole // 60)
        else string.format("%s%d:%02d h", sign, whole // 60, whole % 60)
    return day .. ", " .. shift
end

local function clocks(ctx: Context, here: Moment?)
    local settings = ctx.data.settings or {}
    local list = {}
    for _, entry in if type(settings.zones) == "table" and #settings.zones > 0 then settings.zones else ZONES do
        local there = moment(ctx, entry.zone)
        if there then
            list[#list + 1] = { label = entry.label, short = string.upper(string.sub(entry.label, 1, 3)),
                time = there.time, hour = there.hour, daytime = there.hour >= 6 and there.hour < 19,
                relative = if here then relative(here, there) else nil }
        end
    end
    return list
end

function worldClock.state(ctx)
    local list = clocks(ctx, nil)
    if #list == 0 then
        return nil
    end
    return { clocks = list, shown = math.min(math.max(1, tonumber((ctx.data.settings or {}).bar) or 1), #list),
        help = list[1].label .. " " .. list[1].time }
end

function worldClock.model(ctx)
    local here = moment(ctx, nil)
    return if here then { clocks = clocks(ctx, here) } else nil
end

function worldClock.content(ctx, width: number?, m)
    width = width or look.width
    m = m or worldClock.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Unavailable"), width)
    end
    local group = { w = width }
    for _, clock in m.clocks do
        group[#group + 1] = ui.row{ w = width - 24, gap = 10, pad = 4,
            look.glyph{ name = if clock.daytime then "sun.max.fill" else "moon.fill", w = 22, h = 22,
                color = "secondaryForeground" },
            ui.column{ gap = 3, center = false, grow = 1,
                look.text{ text = clock.label, size = 13, weight = "medium", maxWidth = 134 },
                look.text{ text = clock.relative, size = 11, color = "secondaryForeground", maxWidth = 134 } },
            look.text{ text = clock.time, size = 22, weight = "medium", maxWidth = 106 } }
    end
    return ui.column{ w = width, gap = 12, center = false,
        look.heading(omniwm.l10n("World Clock"), width),
        look.group(group) }
end

function worldClock.popout(ctx)
    local m = worldClock.model(ctx)
    return look.worldClockPanel and look.worldClockPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28, worldClock.content(ctx, nil, m) })
end

return table.freeze(worldClock)
