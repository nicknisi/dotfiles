-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local MOTION = { response = 0.38, bounce = 0.14 }
local CONTENT_MOTION = { response = 0.30, bounce = 0.08 }
local IDLE_SECONDS = 2.6
local TILE = 46
local GAP = 10
local FOREGROUND = "#f6f6f7"
local SECONDARY = "#a7a9b2"

local function cancel(state)
    if state.timer then
        state.timer:cancel()
        state.timer = nil
    end
end

local function collapse(ctx)
    cancel(ctx.state)
    ctx.state.expanded = false
end

local function expand(ctx)
    local state = ctx.state
    cancel(state)
    if state.hovered then
        state.expanded = true
        return
    end
    local timer, err = omniwm.after(IDLE_SECONDS, function()
        state.timer = nil
        state.expanded = false
    end)
    state.timer = timer
    state.expanded = timer ~= nil
    if not timer then
        omniwm.log("Focus Ribbon could not schedule collapse: " .. tostring(err))
    end
end

local function hover(ctx, event)
    local state = ctx.state
    if event.phase == "began" then
        state.hovered = true
        cancel(state)
    elseif event.phase == "ended" then
        state.hovered = false
        if state.expanded then
            expand(ctx)
        end
    end
end

local function toggle(ctx)
    if ctx.state.expanded then
        collapse(ctx)
    else
        expand(ctx)
    end
end

local function reconcile(ctx, navigation)
    local state = ctx.state
    if state.workspace == nil then
        state.workspace = navigation.workspace
        state.focused = navigation.focused
        return
    end
    if state.workspace ~= navigation.workspace then
        state.workspace = navigation.workspace
        state.focused = navigation.focused
        expand(ctx)
    elseif navigation.focused ~= nil and state.focused ~= navigation.focused then
        state.focused = navigation.focused
        if navigation.layout == "niri" then
            expand(ctx)
        end
    end
end

local function outline(width: number, height: number, radius: number): string
    local r = math.min(radius, width / 2, height)
    return string.format("M0 0 H%.2f V%.2f Q%.2f %.2f %.2f %.2f H%.2f Q0 %.2f 0 %.2f Z",
        width, height - r, width, height, width - r, height, r, height, height - r)
end

local function focused(ctx, navigation)
    local id = navigation.focused or ctx.state.focused
    local selected, index, columns = nil, 0, 0
    for position, window in navigation.windows do
        columns = math.max(columns, window.column)
        if window.id == id then
            selected = window
            index = position
        end
    end
    local position = if selected and navigation.layout == "niri" and selected.column > 0
        then tostring(selected.column) .. "/" .. tostring(columns)
        elseif selected then tostring(index) .. "/" .. tostring(#navigation.windows)
        else tostring(#navigation.windows)
    return selected, index, position
end

local function context(navigation, selected, position: string, width: number, height: number, notch, left: number)
    local leftWidth = if notch then math.max(0, notch.x - left - 24) else math.max(0, width - 108)
    local rightX = if notch then math.clamp(notch.x + notch.w - left + 12, 0, width) else math.max(0, width - 88)
    local rightWidth = math.max(0, width - rightX - 12)
    local tree = { key = "context", w = width, h = height, align = "top", onClick = toggle }
    if leftWidth >= 20 then
        local label = { key = "app", w = leftWidth, h = height, gap = 6, align = "topLeading", dx = 12,
            if selected then ui.icon{ key = "icon", app = selected.bundle, w = 20, h = 20,
                placeholder = "app.dashed" }
                else ui.symbol{ key = "icon", name = "rectangle.3.group", w = 20, h = 20, color = FOREGROUND } }
        if leftWidth > 36 then
            label[#label + 1] = ui.text{ key = "name", text = if selected then selected.name else navigation.name,
                size = 12, color = FOREGROUND, maxWidth = leftWidth - 26 }
        end
        tree[#tree + 1] = ui.row(label)
    end
    if rightWidth > 0 then
        tree[#tree + 1] = ui.stack{ key = "workspace", w = rightWidth, h = height, align = "topLeading", dx = rightX,
            ui.text{ text = navigation.name .. " · " .. position, size = 11, color = SECONDARY,
                maxWidth = rightWidth } }
    end
    return ui.stack(tree)
end

local function ribbon(ctx, navigation, selected, index: number, width: number, height: number, top: number)
    local viewportWidth = math.max(1, width - 32)
    local viewportHeight = math.max(0, math.min(54, height - top - 36))
    local count = #navigation.windows
    local extent = count * TILE + math.max(0, count - 1) * GAP
    local offset = if extent <= viewportWidth then (viewportWidth - extent) / 2
        else math.clamp(viewportWidth / 2 - (math.max(1, index) - 1) * (TILE + GAP) - TILE / 2,
            viewportWidth - extent, 0)
    local track = { key = "track", w = extent, h = viewportHeight, gap = GAP, align = "topLeading", dx = offset,
        animate = CONTENT_MOTION }
    for _, window in navigation.windows do
        local active = selected and selected.id == window.id
        local title = if window.title and window.title ~= "" then window.name .. " — " .. window.title else window.name
        track[#track + 1] = ui.stack{ key = window.id, w = TILE, h = TILE, radius = 13,
            fill = if active then "#ffffff17" else nil, hover = "#ffffff20", help = title, animate = CONTENT_MOTION,
            onClick = function(next)
                omniwm.run("window focus " .. window.id)
                expand(next)
            end,
            ui.icon{ key = "icon", app = window.bundle, w = 30, h = 30, placeholder = "app.dashed",
                dy = if active then -2 else 0, animate = CONTENT_MOTION },
            if active then ui.box{ key = "selected", w = 3, h = 3, radius = 1.5, fill = FOREGROUND,
                align = "bottom", dy = -2 } else nil }
    end
    local caption = selected and selected.title
    if not caption or caption == "" then
        caption = if selected then selected.name
            elseif count == 0 then omniwm.l10n("No windows") else navigation.name
    end
    return ui.column{ key = "ribbon", w = viewportWidth, gap = 7, align = "top", dy = top + 6,
        appear = { opacity = 0, dy = -8, animate = CONTENT_MOTION },
        exit = { opacity = 0, dy = -8, animate = 0.14 },
        ui.stack{ key = "viewport", w = viewportWidth, h = viewportHeight,
            ui.path{ key = "clip", w = viewportWidth, h = viewportHeight, viewBox = { 0, 0, 1, 1 },
                d = "M0 0 H1 V1 H0 Z", mask = true }, ui.row(track) },
        ui.stack{ key = "caption", w = viewportWidth, h = 16,
            ui.text{ key = "title", text = caption, size = 12, color = FOREGROUND,
                maxWidth = viewportWidth } } }
end

function render(ctx)
    local island = ctx.data.island
    local navigation = island and island.navigation
    if not navigation then
        collapse(ctx)
        ctx.state.workspace = nil
        ctx.state.focused = nil
        ctx.state.hovered = false
        return ui.box{ w = 0, h = 0 }
    end
    reconcile(ctx, navigation)
    local availableWidth = math.max(1, island.size.w)
    local availableHeight = math.max(1, island.size.h)
    local notch = island.notch
    local compactWidth = math.min(availableWidth, if notch then math.max(256, notch.w + 220) else 256)
    local compactHeight = math.min(availableHeight, math.max(36, notch and notch.h or 0))
    local expanded = ctx.state.expanded == true
    local width = if expanded then math.min(availableWidth, math.max(450, compactWidth)) else compactWidth
    local height = if expanded then math.min(availableHeight, compactHeight + 94) else compactHeight
    local center = math.clamp(if notch then notch.x + notch.w / 2 else availableWidth / 2,
        width / 2, availableWidth - width / 2)
    local selected, index, position = focused(ctx, navigation)
    local panel = { key = "island", w = width, h = height, align = "top", dx = center - availableWidth / 2,
        fill = "#08090b", animate = MOTION, onHover = hover, onOutsidePress = if expanded then collapse else nil,
        ui.path{ key = "shape", w = width, h = height, viewBox = { 0, 0, width, height }, mask = true,
            d = outline(width, height, if expanded then 26 else 18), animate = MOTION },
        context(navigation, selected, position, compactWidth, compactHeight, notch, center - compactWidth / 2) }
    if expanded then
        panel[#panel + 1] = ribbon(ctx, navigation, selected, index, width, height, compactHeight)
    end
    return ui.stack{ w = availableWidth, h = availableHeight, ui.stack(panel) }
end
