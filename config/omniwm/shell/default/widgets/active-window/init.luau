-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

local function model(ctx)
    local data = ctx.data
    if data.app == "" then
        return nil
    end
    local settings = data.settings or {}
    local display = settings.display or "icon_and_text"
    local showText = display ~= "icon_only" and not data.bar.style.vertical
    return { app = data.app, bundle = data.bundle, display = display,
        title = if data.title ~= "" then data.title else data.app,
        help = if data.title ~= "" then data.app .. " — " .. data.title else data.app,
        showIcon = display ~= "text_only" or not showText, showText = showText,
        maxWidth = tonumber(settings.maxWidth) or 260 }
end

function render(ctx)
    local m = model(ctx)
    if not m then
        return ui.box{ w = 0, h = 0 }
    end
    local behaviour = { onClick = "open-command-palette windows", help = m.help }
    local button = look.activeWindowBar and look.activeWindowBar(ctx, m)
    if not button then
        local scale = look.scale(ctx)
        local props = table.clone(behaviour)
        if m.showIcon then
            props[#props + 1] = ui.icon{ app = m.bundle, w = 18 * scale, h = 18 * scale, placeholder = "app.dashed" }
        end
        if m.showText then
            props[#props + 1] = look.text{ text = m.title, size = 13 * scale, weight = "medium", maxWidth = m.maxWidth }
        end
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end
