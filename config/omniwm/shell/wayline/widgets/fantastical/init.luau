-- Clock plus next meeting (macOS calendars via EventKit). Click opens Fantastical's mini calendar;
-- right-click shows OmniWM's built-in calendar popout.
interval = 60

local look = require("../lib/look")
local calendar = require("../lib/calendar")

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

-- One pill: the next meeting (if within 12h) takes the date's slot, so the widget stays clock-sized.
function render(ctx)
    local m = clock(ctx)
    local state = calendar.state(ctx)
    local event = state and state.event
    if event then
        local title = event.title
        if utf8.len(title) and utf8.len(title) > MAX_TITLE then
            title = string.sub(title, 1, utf8.offset(title, MAX_TITLE) - 1) .. "…"
        end
        m.date = title .. " · " .. event.countdown
    end
    local button = look.clockBar(ctx, m)
    button.onClick, button.onRightClick, button.help = fantastical, ui.popout, event and event.title or "Fantastical"
    return button
end

function popout(ctx)
    return calendar.popout(ctx)
end
