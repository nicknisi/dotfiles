-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local calendar = require("../lib/calendar")

local function parts(ctx)
    local data = ctx.data
    local hour, minute, meridiem = string.match(string.gsub(data.clock, "\u{202F}", " "), "^(%d+)[:.](%d%d)%s*(%a*)$")
    if not hour then
        hour, minute, meridiem = os.date("%H"), os.date("%M"), ""
    end
    return { time = data.clock, date = data.date, hour = string.format("%02d", tonumber(hour)), minute = minute,
        meridiem = if meridiem ~= "" then string.lower(meridiem) else nil,
        showDate = ctx.select("settings", "date") ~= false, showIcon = ctx.select("settings", "icon") == true }
end

function render(ctx)
    local m = parts(ctx)
    local click = look.clockClick
    local behaviour = { onClick = click or ui.popout, onRightClick = if click then ui.popout else nil }
    local button = look.clockBar and look.clockBar(ctx, m)
    if not button then
        local scale = look.scale(ctx)
        local props = table.clone(behaviour)
        if ctx.data.bar.style.vertical then
            props.gap = 0
            props.pad = 2 * scale
            if m.showIcon then
                props[#props + 1] = look.glyph{ name = "calendar", size = 12 * scale }
            end
            props[#props + 1] = look.text{ text = m.hour, size = 11 * scale, weight = "medium" }
            props[#props + 1] = look.text{ text = m.minute, size = 11 * scale }
            if m.meridiem then
                props[#props + 1] = look.text{ text = m.meridiem, size = 9 * scale, color = "secondaryForeground" }
            end
        else
            props.gap = 8 * scale
            if m.showIcon then
                props[#props + 1] = look.glyph{ name = "calendar", size = look.px(ctx, "symbol") }
            end
            if m.showDate then
                props[#props + 1] = look.text{ text = m.date, size = 13 * scale, color = "secondaryForeground" }
            end
            props[#props + 1] = look.text{ text = m.time, size = 13 * scale, weight = "medium", reserve = "00:00 PM" }
        end
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

function popout(ctx)
    return calendar.popout(ctx)
end
