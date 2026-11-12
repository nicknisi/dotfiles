-- Clock plus next meeting (macOS calendars via EventKit). Click opens Fantastical's mini calendar;
-- right-click shows OmniWM's built-in calendar popout.
interval = 30 -- the Phosphor clock's blinking cursor needs a redraw at least every 30s

local look = require("../lib/look")
local calendar = require("../lib/calendar")
local effects = require("../lib/effects")

local function fantastical()
    -- Delay so the popover isn't dismissed by the click that opened it.
    omniwm.after(0.25, function() omniwm.open("x-fantastical3://show/mini") end)
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
local function nextMeeting(ctx)
    local cal = ctx.data.calendar
    if not cal or cal.access ~= "full" then return nil end
    local now = ctx.data.seconds
    for _, event in cal.events do
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
    button.onClick, button.onRightClick, button.help = fantastical, ui.popout, event and event.title or "Fantastical"
    -- From 5 minutes before a meeting until 5 minutes in, a rotating accent border nudges you to go.
    if event and math.abs(event.start - ctx.data.seconds) <= 300 then
        local size = 32 * ctx.data.bar.style.height / 40
        return ui.stack{ onClick = fantastical, onRightClick = ui.popout, help = event.title, button,
            effects.shader("rotating-border", { values = { math.floor(size * 0.24), 2, 90, 1 } }) }
    end
    return button
end

function popout(ctx)
    return calendar.popout(ctx)
end
