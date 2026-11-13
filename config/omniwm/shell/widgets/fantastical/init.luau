-- Clock plus next meeting. Click opens the calendar popout: upcoming meetings with their details and a
-- Join button, above OmniWM's month grid. Meeting data (join links live in event notes, which OmniWM's
-- own calendar data lacks) is pushed by omniwm-calendar (config/omniwm/calendar) via
-- `omniwmctl shell set meetings <json>`; without it the popout falls back to OmniWM's built-in one.
-- (Still named "fantastical" because every bar profile places it under that name.)
interval = 30 -- the Phosphor clock's blinking cursor needs a redraw at least every 30s

local look = require("../lib/look")
local calendar = require("../lib/calendar")
local effects = require("../lib/effects")

local STALE = 300 -- seconds without a push before falling back to OmniWM's calendar data

-- omniwm-calendar's events, or nil when it isn't running.
local function meetings(ctx)
    local raw = ctx.data.vars.meetings
    if not raw then return nil end
    if ctx.state.raw ~= raw then
        ctx.state.raw, ctx.state.meetings = raw, json.decode(raw)
    end
    local m = ctx.state.meetings
    if type(m) ~= "table" or type(m.events) ~= "table" or ctx.data.seconds - (m.updated or 0) > STALE then
        return nil
    end
    return m.events
end

-- Same clock model as the built-in clock widget.
local function clock(ctx)
    local data = ctx.data
    local hour, minute, meridiem = string.match(string.gsub(data.clock, "\u{202F}", " "), "^(%d+)[:.](%d%d)%s*(%a*)$")
    if not hour then
        hour, minute, meridiem = os.date("%H"), os.date("%M"), ""
    end
    return { time = data.clock, date = data.date, hour = string.format("%02d", tonumber(hour)), minute = minute,
        meridiem = if meridiem ~= "" then string.lower(meridiem) else nil, showDate = true, showIcon = true }
end

local MAX_TITLE = 18

-- The next timed meeting, only once it's within the hour (keeps the bar narrow the rest of the time).
-- omniwm-calendar's list leaves out declined meetings; OmniWM's own doesn't.
local function nextMeeting(ctx)
    local events = meetings(ctx)
    if not events then
        local cal = ctx.data.calendar
        if not cal or cal.access ~= "full" then return nil end
        events = cal.events
    end
    local now = ctx.data.seconds
    for _, event in events do
        if not event.allDay and event["end"] > now then
            if event.start - now > 3600 then return nil end
            local mins = math.ceil((event.start - now) / 60)
            return event, if mins <= 0 then "now" else mins .. "m"
        end
    end
    return nil
end

-- One pill: a meeting within the hour takes the date's slot, so the widget stays clock-sized.
function render(ctx)
    local m = clock(ctx)
    local event, countdown = nextMeeting(ctx)
    if event then
        local title = event.title
        if utf8.len(title) and utf8.len(title) > MAX_TITLE then
            title = string.sub(title, 1, utf8.offset(title, MAX_TITLE) - 1) .. "…"
        end
        m.date = title .. " · " .. countdown
    end
    local button = look.clockBar(ctx, m)
    button.onClick, button.help = ui.popout, event and event.title or "Calendar"
    -- From 5 minutes before a meeting until 5 minutes in, a rotating accent border nudges you to go.
    if event and math.abs(event.start - ctx.data.seconds) <= 300 then
        local size = 32 * ctx.data.bar.style.height / 40
        return ui.stack{ onClick = ui.popout, help = event.title, button,
            effects.shader("rotating-border", { values = { math.floor(size * 0.24), 2, 90, 1 } }) }
    end
    return button
end

local RESET = 300 -- seconds after picking a day before the popout goes back to today
local lastPick = 0

local function dayKey(seconds: number?): string
    return os.date("%Y-%m-%d", seconds) :: string
end

local function heading(ctx, key: string, seconds: number): string
    if key == dayKey(ctx.data.seconds) then return omniwm.l10n("Today") end
    if key == dayKey(ctx.data.seconds + 86400) then return omniwm.l10n("Tomorrow") end
    return ctx.format.date(seconds, "EEEEMMMMd") or key
end

-- The day's events: omniwm-calendar's (join links, no declined meetings) for today when it's running,
-- otherwise OmniWM's own, with links filled in from omniwm-calendar wherever it has the same event.
local function dayEvents(ctx, key: string)
    local helper = meetings(ctx)
    local function onDay(event)
        return dayKey(event.start) <= key and dayKey(math.max(event.start, event["end"] - 1)) >= key
    end
    local events = {}
    if helper and key == dayKey(ctx.data.seconds) then
        for _, event in helper do
            if table.find(event.days or {}, key) then events[#events + 1] = event end
        end
        return events
    end
    local extra, seen = {}, {}
    for _, event in helper or {} do extra[event.title .. "|" .. event.start] = event end
    for _, event in (ctx.data.calendar and ctx.data.calendar.events) or {} do
        -- The same event on two calendars (work + family) shows once.
        local id = event.title .. "|" .. math.floor(event.start)
        if onDay(event) and not seen[id .. "|" .. math.floor(event["end"])] then
            seen[id .. "|" .. math.floor(event["end"])] = true
            events[#events + 1] = extra[id] or event
        end
    end
    return events
end

-- The popout's agenda for one day, in lib/calendar.luau's model shape plus the extras that the look's
-- calendarPanel draws (see calendarAgenda in lib/wayline-base.luau): all-day events first as quiet
-- one-liners, then meetings with details and a Join button.
local function agenda(ctx, key: string, seconds: number)
    local now, today = ctx.data.seconds, key == dayKey(ctx.data.seconds)
    local rows, timed = { { heading = heading(ctx, key, seconds) } }, {}
    for _, event in dayEvents(ctx, key) do
        if event.allDay then
            rows[#rows + 1] = { subtle = true, title = event.title, color = event.color }
        else
            timed[#timed + 1] = event
        end
    end
    table.sort(timed, function(a, b) return a.start < b.start end)
    for _, event in timed do
        local row = { title = event.title, color = event.color, past = event["end"] <= now,
            when = (ctx.format.date(event.start, "jmm") or "") .. " - " .. (ctx.format.date(event["end"], "jmm") or "") }
        if today and not row.past then
            local mins = math.ceil((event.start - now) / 60)
            row.countdown = if mins <= 0 then omniwm.l10n("Now") elseif mins < 60 then omniwm.l10n("In %lld min", mins) else nil
        end
        local details = {}
        if event.location then details[#details + 1] = (string.gsub(event.location, "%s*\n%s*", ", ")) end
        if event.organizer then details[#details + 1] = event.organizer end
        if (event.attendees or 0) > 1 then details[#details + 1] = event.attendees .. " people" end
        if #details > 0 then row.detail = table.concat(details, " · ") end
        if event.join and not row.past then
            local url = event.join
            row.join, row.joinLabel = function() omniwm.open(url) end, event.service
            -- The Join button takes the countdown's spot, so fold the countdown into the time line.
            if row.countdown then row.when ..= " · " .. row.countdown end
        end
        rows[#rows + 1] = row
    end
    if #rows == 1 then
        rows[#rows + 1] = { subtle = true, title = omniwm.l10n("No events") }
    end
    return rows
end

function popout(ctx)
    local m = calendar.model(ctx)
    if not m or m.access ~= "full" or not m.month then return calendar.popout(ctx) end
    local month = m.month
    local key = ctx.data.calendar.selectedDay or dayKey(ctx.data.seconds)
    local y, mo, d = string.match(key, "^(%d+)-(%d+)-(%d+)$")
    if tonumber(y) == month.year and tonumber(mo) == month.month then month.selected = tonumber(d) end
    -- Clicking a day shows its events (`calendar day`); today, or RESET seconds later, goes back to today.
    month.select = function(day)
        local picked = string.format("%04d-%02d-%02d", month.year, month.month, day)
        return function()
            if picked == dayKey(os.time()) then
                omniwm.run("calendar month today")
                return
            end
            omniwm.run("calendar day " .. picked)
            lastPick += 1
            local mine = lastPick
            omniwm.after(RESET, function()
                if lastPick == mine then omniwm.run("calendar month today") end
            end)
        end
    end
    local noon = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 })
    m.agenda = agenda(ctx, key, noon or ctx.data.seconds)
    return if look.calendarPanel then look.calendarPanel(ctx, m) else look.panel(ctx, { calendar.content(ctx, nil, m) })
end
