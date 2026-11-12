-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")
local actions = require("./actions")

local calendar = {}
local SOON = 12 * 3600
local AGENDA = 6
local PRECISE_POINTS_PER_STEP = 12
local PREVIOUS = "calendar month previous"
local NEXT = "calendar month next"

local function countdown(now: number, event): string?
    local minutes = math.ceil((event.start - now) / 60)
    if minutes <= 0 then
        return omniwm.l10n("Now")
    end
    if minutes < 60 then
        return omniwm.l10n("In %lld min", minutes)
    end
    return nil
end

local function scroll(ctx, event)
    local delta = if event.precise then event.dy / PRECISE_POINTS_PER_STEP else event.dy
    local total = ctx.state.monthScroll or 0
    if total * delta < 0 then
        total = 0
    end
    total += delta
    local steps = if total >= 0 then math.floor(total) else math.ceil(total)
    ctx.state.monthScroll = total - steps
    for _ = 1, math.abs(steps) do
        omniwm.run(if steps > 0 then PREVIOUS else NEXT)
    end
end

function calendar.state(ctx)
    local data = ctx.data.calendar
    if not data then
        return nil
    end
    local state = {}
    if data.access ~= "full" then
        return state
    end
    local now = ctx.data.seconds
    for _, event in data.events do
        if not event.allDay and event["end"] > now then
            if event.start - now < SOON then
                state.event = { title = event.title, color = event.color,
                    countdown = countdown(now, event) or event.time }
            end
            break
        end
    end
    return state
end

function calendar.model(ctx, compact: boolean?)
    local data = ctx.data.calendar
    if not data then
        return nil
    end
    local m = { access = data.access, previous = PREVIOUS, next = NEXT, today = "calendar month today",
        open = "calendar open", scroll = scroll }
    local month = data.month
    if month then
        local marked = {}
        for _, day in month.marked do
            marked[day] = true
        end
        m.month = { title = month.title, year = month.year, month = month.month,
            weekdays = month.weekdays, offset = month.offset, days = month.days,
            today = month.today, marked = marked }
    end
    if data.access == "full" then
        if compact then
            return m
        end
        local now = ctx.data.seconds
        local limit = tonumber((ctx.data.settings or {}).agendaEvents) or AGENDA
        m.agenda = {}
        for _, event in data.events do
            if event["end"] > now then
                m.agenda[#m.agenda + 1] = { title = event.title, color = event.color, day = event.day,
                    allDay = event.allDay, when = if event.allDay then omniwm.l10n("All day") else event.time,
                    countdown = if event.allDay then nil else countdown(now, event), open = "calendar open " .. event.id }
                if #m.agenda >= limit then
                    break
                end
            end
        end
    elseif data.access == "notDetermined" then
        m.action = { symbol = "calendar.badge.plus", text = omniwm.l10n("Allow Calendar Access"),
            command = "calendar authorize" }
    else
        m.action = { symbol = "lock.fill", text = omniwm.l10n("Open Calendar Privacy Settings"),
            command = "calendar settings" }
    end
    return m
end

local function grid(month, width: number)
    local cell = (width - 24) / 7
    local rows = { gap = 2, center = false }
    local header = { gap = 0 }
    for _, symbol in month.weekdays do
        header[#header + 1] = ui.stack{ w = cell, h = 22,
            look.text{ text = symbol, size = 11, color = "secondaryForeground" } }
    end
    rows[#rows + 1] = ui.row(header)
    local week = { gap = 0 }
    for _ = 1, month.offset do
        week[#week + 1] = ui.box{ w = cell, h = 34 }
    end
    for day = 1, month.days do
        local today = day == month.today
        week[#week + 1] = ui.column{ w = cell, h = 34, gap = 2, center = true,
            ui.stack{ w = 26, h = 26, radius = look.radius(13), fill = if today then "accent" else nil,
                look.text{ text = tostring(day), size = 13, weight = if today then "semibold" else nil,
                    color = if today then "accentForeground" else "foreground" } },
            ui.box{ w = 4, h = 4, radius = 2, fill = if month.marked[day] then "secondaryForeground" else nil } }
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

local function agendaRow(event, width: number)
    local row = { w = width - 24, gap = 8, pad = 4, radius = look.radius(6), hover = look.hover, onClick = event.open,
        ui.box{ w = 3, h = 34, radius = 1.5, fill = event.color },
        ui.column{ gap = 3, center = false,
            look.text{ text = event.title, size = 13, weight = "medium", maxWidth = width - 48 },
            look.text{ text = event.day .. " · " .. event.when, size = 11, color = "secondaryForeground",
                maxWidth = width - 48 } } }
    if event.countdown then
        row[#row + 1] = ui.box{ grow = 1, h = 1 }
        row[#row + 1] = look.text{ text = event.countdown, size = 11, weight = "semibold", color = "accent" }
    end
    return ui.row(row)
end

function calendar.content(ctx, width: number?, m)
    width = width or look.width
    m = m or calendar.model(ctx)
    if not m then
        return actions.notice(omniwm.l10n("Loading…"), width)
    end
    local rows = { w = width, gap = 12, center = false }
    if m.month then
        rows[#rows + 1] = ui.row{ w = width, gap = 4,
            look.text{ text = m.month.title, size = 14, weight = "semibold", grow = 1, maxWidth = width - 104 },
            look.button("chevron.left", m.previous),
            look.button("circle.fill", m.today),
            look.button("chevron.right", m.next) }
        rows[#rows + 1] = look.group{ w = width, onScroll = m.scroll, grid(m.month, width) }
    end
    if m.agenda then
        local agenda = { w = width }
        for _, event in m.agenda do
            agenda[#agenda + 1] = agendaRow(event, width)
        end
        if #agenda == 0 then
            agenda[#agenda + 1] = look.text{ text = omniwm.l10n("No upcoming events"), size = 13,
                color = "secondaryForeground", maxWidth = width - 24 }
        end
        rows[#rows + 1] = look.group(agenda)
    elseif m.action then
        rows[#rows + 1] = actions.row(m.action.symbol, m.action.text, m.action.command, width, true)
    end
    rows[#rows + 1] = actions.row("arrow.up.forward.app", omniwm.l10n("Open Calendar"), m.open, width, true)
    return ui.column(rows)
end

function calendar.popout(ctx)
    local m = calendar.model(ctx)
    return m and look.calendarPanel and look.calendarPanel(ctx, m) or look.panel(ctx, { calendar.content(ctx, nil, m) })
end

return table.freeze(calendar)
