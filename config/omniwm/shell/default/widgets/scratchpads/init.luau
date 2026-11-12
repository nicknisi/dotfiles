-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

spanIslands = true

local look = require("../lib/look")

local SHOWN_ICONS = 3
local MAX_ICONS = 6
local COMPACT_LABEL = 20

type Metrics = {
    vertical: boolean,
    item: number,
    icon: number,
    slot: number,
    margin: number,
    scale: number,
    gap: number,
    compactGap: number,
    edge: number,
    compactEdge: number,
    spacing: number,
    focusCue: boolean,
    shown: number,
}

local function metrics(ctx: Context, style: BarStyle, settings): Metrics
    local shown = if type(settings.shownWindows) == "number" then settings.shownWindows else SHOWN_ICONS
    local m = { vertical = style.vertical, item = math.max(16, style.height - 4), icon = look.px(ctx, "icon"),
        scale = look.scale(ctx), gap = 5, compactGap = 3, edge = 3, compactEdge = 2, spacing = 8, focusCue = false,
        shown = math.clamp(math.floor(if shown == shown then shown else 0), 0, MAX_ICONS) }
    if look.scratchpadMetrics then
        for key, value in look.scratchpadMetrics(ctx, style, m) or {} do
            m[key] = value
        end
    end
    m.slot = m.slot or m.icon
    m.margin = (m.slot - m.icon) / 2
    return m
end

local function line(vertical: boolean, props)
    return vertical and ui.column(props) or ui.row(props)
end

local function spacer(vertical: boolean, length: number)
    return vertical and ui.box{ w = 1, h = length } or ui.box{ w = length, h = 1 }
end

local function countBadge(text: string, scratchpad: BarScratchpad, style: BarStyle, m: Metrics)
    if look.scratchpadCount then
        local custom = look.scratchpadCount(text, scratchpad, style, m)
        if custom then
            return custom
        end
    end
    local size = math.max(12, m.icon * 0.55)
    return ui.row{ h = size, radius = size / 2, fill = "surface",
        ui.box{ w = 3, h = 1 },
        look.text{ text = text, style = "mono", size = 10, weight = "semibold", color = "foreground" },
        ui.box{ w = 3, h = 1 } }
end

local function notificationBadge(item: BarItem, mode: string, m: Metrics)
    if mode == "off" or item.badge == "" then
        return nil
    end
    return look.notificationBadge(item, mode, m)
end

local function initial(name: string): string
    local next = utf8.offset(name, 2)
    return if next then string.sub(name, 1, next - 1) else name
end

local function windowCount(scratchpad: BarScratchpad): number
    local count = 0
    for _, item in ipairs(scratchpad.windows) do
        count += item.count
    end
    return count
end

local function help(scratchpad: BarScratchpad, bar: Bar, m: Metrics): string
    local count = windowCount(scratchpad)
    local summary = count == 1 and scratchpad.windows[1].name or omniwm.l10n("%lld windows", count)
    local text = scratchpad.visible and omniwm.l10n("Scratchpad %@: %@, visible", scratchpad.name, summary)
        or omniwm.l10n("Scratchpad %@: %@, hidden", scratchpad.name, summary)
    if bar.badges ~= "off" and not scratchpad.compact then
        for index, item in ipairs(scratchpad.windows) do
            if index > m.shown then
                break
            end
            if item.badge ~= "" then
                text ..= ", " .. omniwm.l10n("%@ notification badge: %@", item.name, item.badge)
            end
        end
    end
    return text
end

local function label(ctx: Context, scratchpad: BarScratchpad, style: BarStyle, m: Metrics)
    local text = if m.vertical then initial(scratchpad.name) else scratchpad.name
    local width = if scratchpad.compact and not m.vertical then COMPACT_LABEL else nil
    if look.scratchpadLabel then
        local custom = look.scratchpadLabel(scratchpad, style, m, text, width)
        if custom then
            return custom
        end
    end
    local accent = (scratchpad.revealed or scratchpad.focused) and style.accents
    local color = accent and "accent" or (style.textColor ~= nil and "foreground" or "secondaryForeground")
    local textSize = look.px(ctx, "text")
    local name = look.text{ text = text, size = if width then math.min(textSize, width / 2) else textSize,
        weight = "medium", color = color, maxWidth = width }
    if scratchpad.compact then
        return name
    end
    return line(m.vertical, { gap = m.gap,
        look.glyph{ name = "tray.fill", size = math.max(10, m.icon * 0.64), weight = "semibold", color = color },
        name })
end

local function windowIcon(member: BarItem, scratchpad: BarScratchpad, bar: Bar, m: Metrics)
    local style = bar.style
    local glyph = { placeholder = "app.dashed", w = m.icon, h = m.icon,
        opacity = member.focused and 1 or (style.inactive >= 0 and style.inactive or 0.82) }
    local slot = { w = m.slot, h = m.slot }
    if look.scratchpadIcon then
        look.scratchpadIcon(slot, glyph, member, scratchpad, style, m)
    end
    glyph.window = member.id
    slot[#slot + 1] = ui.icon(glyph)
    slot[#slot + 1] = notificationBadge(member, bar.badges, m)
    return ui.stack(slot)
end

local function pill(ctx: Context, scratchpad: BarScratchpad, bar: Bar, m: Metrics)
    local style = bar.style
    local compact = scratchpad.compact
    local edge = if compact then m.compactEdge else m.edge
    local node = { gap = if compact then m.compactGap else m.gap, radius = look.radius(6 * m.scale),
        animate = 0.15, hoverAnimate = 0.12, hover = look.hover,
        w = if m.vertical then m.item else nil, h = if m.vertical then nil else m.item,
        fill = scratchpad.focused and "foreground/0.1" or (style.backgrounds and "foreground/0.04" or nil),
        spacer(m.vertical, edge), label(ctx, scratchpad, style, m) }
    if compact then
        node[#node + 1] = countBadge(tostring(windowCount(scratchpad)), scratchpad, style, m)
    else
        for index, member in ipairs(scratchpad.windows) do
            if index > m.shown then
                node[#node + 1] = countBadge("+" .. tostring(#scratchpad.windows - m.shown), scratchpad, style, m)
                break
            end
            node[#node + 1] = windowIcon(member, scratchpad, bar, m)
        end
    end
    node[#node + 1] = spacer(m.vertical, edge)
    if look.scratchpadPill then
        look.scratchpadPill(node, scratchpad, style, m)
    end
    local focusScale = scratchpad.focused and 1.04 or 1
    node.key = "scratchpad " .. scratchpad.id
    node.scale = focusScale
    node.hoverScale = math.max(node.hoverScale or 1.03, focusScale)
    node.onClick = "scratchpad toggle " .. scratchpad.id
    node.target = "scratchpad " .. scratchpad.id
    node.menu = true
    node.help = help(scratchpad, bar, m)
    if scratchpad.focused and style.accents and not m.focusCue then
        node.border = "accent"
        node.borderWidth = 1.2
    end
    return line(m.vertical, node)
end

function render(ctx: Context)
    local bar = ctx.data.bar
    if bar.island == "active" then
        return ui.row{}
    end
    local m = metrics(ctx, bar.style, ctx.data.settings or {})
    local items = { gap = m.spacing }
    for _, scratchpad in ipairs(bar.scratchpads) do
        items[#items + 1] = pill(ctx, scratchpad, bar, m)
    end
    if look.scratchpadGroup then
        local custom = look.scratchpadGroup(ctx, items, bar.style, m)
        if custom then
            return custom
        end
    end
    return line(m.vertical, items)
end
