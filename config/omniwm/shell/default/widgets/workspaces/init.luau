-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

spanIslands = true

local look = require("../lib/look")

local WHITE = "#FFFFFFFF"

type Metrics = {
    across: number,
    item: number,
    icon: number,
    slot: number,
    margin: number,
    scale: number,
    vertical: boolean,
    capsule: boolean,
    indicator: string,
    compact: boolean,
    occupiedBackground: boolean,
    markerAlways: boolean,
    focusCue: boolean,
    separator: boolean,
}

local INDICATORS = { pills = true, underline = true, dots = true, numbers = true, minimal = true }

local function metrics(ctx: Context, style: BarStyle, settings): Metrics
    local capsule = style.transparent and style.backgrounds
    local indicator = if INDICATORS[settings.indicator] then settings.indicator else "pills"
    local across = math.max(16, style.height - 4)
    local m = { across = across, item = if capsule and indicator ~= "pills" then across - 4 else across,
        icon = look.px(ctx, "icon"), slot = look.px(ctx, "slot"), scale = look.scale(ctx),
        vertical = style.vertical, capsule = capsule, indicator = indicator, compact = settings.compact == true,
        occupiedBackground = settings.occupiedBackground == true,
        markerAlways = false, focusCue = false, separator = true }
    if look.workspaceMetrics then
        for key, value in look.workspaceMetrics(ctx, style, m) or {} do
            m[key] = value
        end
    end
    m.margin = (m.slot - m.icon) / 2
    return m
end

local function line(vertical: boolean, props)
    return vertical and ui.column(props) or ui.row(props)
end

local function spacer(vertical: boolean, length: number)
    return vertical and ui.box{ w = 1, h = length } or ui.box{ w = length, h = 1 }
end

local function contains(list: { string }?, value: string): boolean
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function appHidden(item: BarItem): boolean
    return item.count > 0 and item.hidden == item.count
end

local function labelColor(style: BarStyle, focused: boolean): Color
    if style.textColor ~= nil then
        return "foreground"
    end
    return (focused and style.accents) and "accent" or (style.solidBlack and "#B8B8C0" or "secondaryForeground")
end

local function iconOpacity(item: BarItem, style: BarStyle, workspaceFocused: boolean): number
    if appHidden(item) then
        return 0.9
    end
    if item.focused then
        return 1
    end
    if style.inactive >= 0 then
        return style.inactive
    end
    return workspaceFocused and 0.4 or 0.5
end

local function extent(node, vertical: boolean): number?
    return if vertical then node.h else node.w
end

local function countBadge(text: string, m: Metrics)
    if look.countBadge then
        local custom = look.countBadge(text, m)
        if custom then
            return custom
        end
    end
    local size = math.max(12, m.icon * 0.55)
    return ui.row{ align = "topTrailing", dx = math.min(0, m.icon * 0.2 - m.margin), dy = m.margin - math.max(5, m.icon * 0.1),
        h = size, radius = size / 2, fill = "surface",
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

local function hiddenIndicator(item: BarItem, m: Metrics)
    if item.hidden == 0 then
        return nil
    end
    if look.hiddenIndicator then
        local custom = look.hiddenIndicator(item, m)
        if custom then
            return custom
        end
    end
    local full = appHidden(item)
    local size = math.max(8, m.icon * 0.48)
    local glyph = math.max(6, m.icon * 0.3)
    return ui.stack{ align = "bottomTrailing", dx = math.min(0, m.icon * 0.2 - m.margin),
        dy = math.max(5, m.icon * 0.1) - m.margin, w = size, h = size, radius = size / 2,
        fill = full and "badge" or nil, material = (not full) and "regular" or nil,
        border = (not full) and "badge/0.72" or nil, borderWidth = 0.75,
        look.glyph{ name = full and "eye.slash.fill" or "eye.slash", size = glyph, weight = full and "bold" or "semibold",
            color = full and WHITE or "badge" } }
end

local function windowHelp(item: BarItem, bar: Bar): string
    local text
    if item.count > 1 then
        text = item.floating and omniwm.l10n("%@, %lld floating windows", item.name, item.count)
            or omniwm.l10n("%@, %lld windows", item.name, item.count)
    else
        text = item.floating and omniwm.l10n("%@ floating window", item.name) or omniwm.l10n("%@ window", item.name)
    end
    if bar.badges ~= "off" and item.badge ~= "" then
        text ..= ", " .. omniwm.l10n("%@ notification badge: %@", item.name, item.badge)
    end
    return text
end

local function windowIcon(item: BarItem, workspace: BarWorkspace, bar: Bar, m: Metrics, shift: number)
    local style = bar.style
    local drag = bar.drag
    local glyph = { window = item.id, placeholder = "app.dashed", w = m.icon, h = m.icon,
        color = appHidden(item) and "error/0.32" or nil }
    local icon = { w = m.slot, h = m.slot, radius = look.radius(4), animate = 0.15, hoverAnimate = 0.1,
        hoverScale = 1.05 }
    if look.windowIcon then
        look.windowIcon(icon, glyph, item, style, m)
    end
    local focusScale = item.focused and 1.1 or 1
    icon.key = item.id
    icon.scale = focusScale
    icon.hoverScale = math.max(icon.hoverScale or 1, focusScale)
    icon.dx = m.vertical and 0 or shift
    icon.dy = m.vertical and shift or 0
    icon.target = "window " .. item.id
    icon.menu = true
    icon.preview = true
    icon.drag = true
    icon.help = windowHelp(item, bar)
    if drag ~= nil and contains(drag.icons, item.id) then
        icon.border = "accent"
        icon.borderWidth = 1.5
    end
    glyph.window = item.id
    glyph.opacity = (drag ~= nil and contains(drag.sources, item.id)) and 0.35 or iconOpacity(item, style, workspace.focused)
    if item.focused and style.accents then
        glyph.shadow = "accent/0.5"
        glyph.shadowRadius = 4
    end
    icon[#icon + 1] = ui.icon(glyph)
    if item.count > 1 then
        icon.onClick = function(ctx) ctx.state.picker = item.id end
        icon.popout = true
        icon[#icon + 1] = countBadge(tostring(item.count), m)
    else
        icon.onClick = "window focus " .. item.id
    end
    icon[#icon + 1] = notificationBadge(item, bar.badges, m)
    icon[#icon + 1] = hiddenIndicator(item, m)
    return ui.stack(icon)
end

local function separator(m: Metrics)
    if m.separator == false or m.indicator == "minimal" or m.indicator == "dots" then
        return nil
    end
    return m.vertical and ui.stack{ w = m.icon, h = 5, ui.box{ w = m.icon, h = 1, fill = "border" } }
        or ui.stack{ w = 5, h = m.icon, ui.box{ w = 1, h = m.icon, fill = "border" } }
end

local function floatingGroup(icons, style: BarStyle, m: Metrics): (any, number?)
    if look.floatingGroup then
        local custom, length = look.floatingGroup(icons, style, m)
        if custom then
            return custom, length
        end
    end
    local thickness = math.max(16, m.item - 2)
    local symbol = math.max(10, m.icon * 0.58)
    local group = { gap = 3, radius = look.radius(6),
        w = if m.vertical then thickness else nil, h = if m.vertical then nil else thickness,
        fill = style.backgrounds and "foreground/0.06" or nil,
        spacer(m.vertical, 2),
        look.glyph{ name = "rectangle.on.rectangle", size = symbol, w = symbol, h = symbol, weight = "medium",
            color = style.textColor ~= nil and "foreground" or "secondaryForeground" } }
    for _, icon in ipairs(icons) do
        group[#group + 1] = icon
    end
    group[#group + 1] = spacer(m.vertical, 2)
    return line(m.vertical, group), 4 + symbol + #icons * m.slot + (#icons + 2) * 3
end

local function gapBefore(drag: BarDrag?, workspace: string): number?
    for _, gap in ipairs(drag and drag.gaps or {}) do
        if gap.workspace == workspace then
            return gap.before
        end
    end
    return nil
end

local function marker(ctx: Context, workspace: BarWorkspace, style: BarStyle, m: Metrics, occupied: boolean)
    if look.workspaceMarker then
        local custom = look.workspaceMarker(ctx, workspace, style, m, occupied)
        if custom then
            return custom
        end
    end
    local focused = workspace.focused
    if m.indicator == "dots" or (m.compact and not style.labels) then
        local dot = math.max(6, math.round(m.icon * 0.32))
        local long = if focused then dot * 2.6 else dot
        return ui.stack{ w = if m.vertical then dot else long, h = if m.vertical then long else dot,
            radius = dot / 2, fill = if focused then "accent" elseif occupied then "foreground/0.55" else nil,
            border = if focused or occupied then nil else "foreground/0.45", borderWidth = 1 }
    end
    if m.indicator == "numbers" then
        local size = math.max(16, math.round(m.icon * 0.95))
        return ui.row{ h = size, radius = look.radius(size * 0.3),
            fill = if focused then "accent" else "foreground/0.1",
            ui.box{ w = if utf8.len(workspace.name) <= 1 then size * 0.32 else 5, h = 1 },
            look.text{ text = workspace.name, size = look.px(ctx, "text"), weight = "medium",
                color = if focused then "accentForeground" else "secondaryForeground",
                maxWidth = if m.vertical then m.item - 10 else nil },
            ui.box{ w = if utf8.len(workspace.name) <= 1 then size * 0.32 else 5, h = 1 } }
    end
    local minimal = m.indicator == "minimal"
    local label = look.text{ text = workspace.name, size = look.px(ctx, "text"),
        weight = focused and "semibold" or "medium",
        color = if minimal and not focused then "mutedForeground"
            elseif minimal or (m.capsule and focused) then "foreground"
            else labelColor(style, focused),
        maxWidth = m.vertical and m.item - 4 or nil, target = "workspace " .. workspace.id,
        help = omniwm.l10n("Focus workspace %@", workspace.name) }
    return utf8.len(workspace.name) <= 2 and ui.stack{
        w = m.vertical and m.item - 4 or (utf8.len(workspace.name) == 1 and 16 or 28) * m.scale,
        h = m.icon, label } or label
end

local function paint(pill, workspace: BarWorkspace, style: BarStyle, m: Metrics, occupied: boolean)
    pill.radius = look.radius(6 * m.scale)
    pill.hover = look.hover
    pill.fill = if m.indicator == "pills" and workspace.focused then "foreground/0.1"
        elseif m.occupiedBackground and occupied and style.backgrounds then "foreground/0.08"
        elseif style.backgrounds then "foreground/0.04" else nil
    if look.workspacePill then
        look.workspacePill(pill, workspace, style, m, occupied)
    end
end

local function underline(pill, m: Metrics)
    local bar = if m.vertical
        then ui.path{ w = 2, align = "leading", viewBox = { 0, 0, 2, 100 }, d = "M0 18 H2 V82 H0 Z", fill = "accent" }
        else ui.path{ h = 2, align = "bottom", viewBox = { 0, 0, 100, 2 }, d = "M10 0 H90 V2 H10 Z", fill = "accent" }
    return ui.stack{ key = pill.key, pill, bar }
end

local function workspacePill(ctx: Context, workspace: BarWorkspace, bar: Bar, m: Metrics)
    local style = bar.style
    local dropTarget = bar.drag ~= nil and contains(bar.drag.workspaces, workspace.id)
    local gap = gapBefore(bar.drag, workspace.id)
    local half = math.min(8, m.icon * 0.4) / 2
    local edge = if m.indicator == "pills" then 6 elseif m.indicator == "minimal" then 3 else 4
    local pill = { gap = if m.indicator == "pills" then 2 else 3, w = if m.vertical then m.item else nil,
        h = if m.vertical then nil else m.item }
    local children = { spacer(m.vertical, edge) }
    local sizes = { edge }
    local tiled, floating = {}, {}
    if not m.compact then
        for _, item in ipairs(workspace.windows) do
            if item.floating then
                floating[#floating + 1] = windowIcon(item, workspace, bar, m, 0)
            else
                local index = #tiled + 1
                tiled[index] = windowIcon(item, workspace, bar, m, gap and (index < gap and -half or half) or 0)
            end
        end
    end
    local occupied = #workspace.windows > 0
    local hasIcons = #tiled + #floating > 0
    if m.compact or m.markerAlways or style.labels or not hasIcons then
        local mark = marker(ctx, workspace, style, m, occupied)
        if mark.target == nil and not (mark[1] and mark[1].target) then
            mark.target = "workspace " .. workspace.id
            mark.help = omniwm.l10n("Focus workspace %@", workspace.name)
        end
        children[#children + 1] = mark
        sizes[#children] = extent(mark, m.vertical) or false
        local rule = if hasIcons then separator(m) else nil
        if rule then
            children[#children + 1] = rule
            sizes[#children] = 5
        end
    end
    for _, icon in ipairs(tiled) do
        children[#children + 1] = icon
        sizes[#children] = m.slot
    end
    if #floating > 0 then
        local rule = if #tiled > 0 then separator(m) else nil
        if rule then
            children[#children + 1] = rule
            sizes[#children] = 5
        end
        local group, span = floatingGroup(floating, style, m)
        children[#children + 1] = group
        sizes[#children] = span or false
    end
    children[#children + 1] = spacer(m.vertical, edge)
    sizes[#children] = edge
    paint(pill, workspace, style, m, occupied)
    local length: number? = math.max(0, #children - 1) * pill.gap
    for index, child in ipairs(children) do
        local size = sizes[index]
        length = if length and size then length + size else nil
        pill[#pill + 1] = child
    end
    pill.key = workspace.id
    pill.onClick = "switch-workspace " .. workspace.id
    pill.target = "workspace " .. workspace.id
    pill.menu = true
    pill.drop = true
    if dropTarget then
        pill.border = "accent"
        pill.borderWidth = 1.5
    elseif m.indicator == "pills" and workspace.focused and style.accents and not m.focusCue then
        pill.border = "accent"
        pill.borderWidth = 1
    end
    local node = line(m.vertical, pill)
    if m.indicator == "underline" and workspace.focused and style.accents then
        node = underline(node, m)
    end
    return node, { workspace = workspace, occupied = occupied, tiled = #tiled, floating = #floating, length = length }
end

local function findItem(bar: Bar, id: string): BarItem?
    for _, workspace in ipairs(bar.workspaces) do
        for _, item in ipairs(workspace.windows) do
            if item.id == id then
                return item
            end
        end
    end
    return nil
end

local function hiddenBadge()
    return ui.row{ gap = 4, h = 18, radius = look.radius(9), fill = "error/0.18", border = "error/0.65", borderWidth = 1,
        ui.box{ w = 3, h = 1 },
        look.glyph{ name = "eye.slash.fill", size = 11, weight = "semibold", color = "foreground" },
        look.text{ text = omniwm.l10n("App hidden"), size = 11, weight = "semibold", color = "foreground" },
        ui.box{ w = 3, h = 1 } }
end

function render(ctx: Context)
    local bar = ctx.data.bar
    local m = metrics(ctx, bar.style, ctx.data.settings or {})
    local pills = { gap = if m.indicator ~= "pills" then 2 else 6 }
    local cells = {}
    for _, workspace in ipairs(bar.workspaces) do
        if bar.island == "all" or workspace.focused == (bar.island == "active") then
            local node, cell = workspacePill(ctx, workspace, bar, m)
            pills[#pills + 1] = node
            cells[#cells + 1] = cell
        end
    end
    if look.workspaceGroup then
        local custom = look.workspaceGroup(ctx, pills, cells, bar.style, m)
        if custom then
            return custom
        end
    end
    if m.capsule and m.indicator ~= "pills" then
        pills.radius = look.radius(6 * m.scale)
        pills.fill = "foreground/0.06"
        pills[if m.vertical then "w" else "h"] = m.across
        pills.pad = 2
    end
    return line(m.vertical, pills)
end

function popout(ctx: Context)
    local item = findItem(ctx.data.bar, ctx.state.picker)
    if not item or item.count < 2 then
        return ui.column{}
    end
    local custom = ctx.data.bar.style.textColor ~= nil
    local width = look.panelWidth("workspaces")
    local rows = { scroll = true, gap = 2 }
    for _, window in ipairs(item.windows) do
        local title = window.title ~= "" and window.title or item.name
        local reserved = (window.focused and 22 or 0) + (window.hidden and 130 or 0)
        local row = { w = width, pad = 8, gap = 6, radius = look.radius(7), hover = look.hover,
            look.text{ text = title, color = (window.focused or custom) and "foreground" or "secondaryForeground",
                size = 13, maxWidth = width - 16 - reserved, lines = 255 },
            ui.box{ grow = 1, h = 1 } }
        if look.pickerRow then
            look.pickerRow(row, window, item)
        end
        if window.focused then
            row[#row + 1] = look.glyph{ name = "checkmark.circle.fill", color = "accent" }
        end
        if window.hidden then
            row[#row + 1] = hiddenBadge()
        end
        row.key = window.id
        row.onClick = "window focus " .. window.id
        row.help = window.hidden and omniwm.l10n("Unhide and focus %@", title) or omniwm.l10n("Focus %@", title)
        rows[#rows + 1] = ui.row(row)
    end
    local header = { w = width, gap = 8,
        look.text{ text = item.name, size = 14, weight = "semibold", maxWidth = width - 60 },
        ui.box{ grow = 1, h = 1 },
        look.button("xmark", ui.popout, { help = omniwm.l10n("Close") }) }
    if look.pickerHeader then
        look.pickerHeader(header, item)
    end
    return look.panel(ctx, { ui.row(header), look.list(rows) })
end
