-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

spanIslands = true
interval = 1

local look = require("../lib/look")

local TRACK = "foreground/0.08"
local GRAPH = 40

local function secondaryHasContent(bar: Bar): boolean
    if #bar.scratchpads > 0 then
        return true
    end
    for _, workspace in ipairs(bar.workspaces) do
        if not workspace.focused then
            return true
        end
    end
    return false
end

function render(ctx: Context)
    local bar = ctx.data.bar
    local style = bar.style
    if not style.statsButton or (bar.island ~= "all" and (bar.island == "secondary") ~= secondaryHasContent(bar)) then
        return ui.row{}
    end
    local behaviour = { onClick = ui.popout, help = omniwm.l10n("Show system stats") }
    local glyph = { name = "gauge.with.needle", size = look.px(ctx, "symbol") }
    local frame = look.systemStatsButton and look.systemStatsButton(ctx, glyph)
    local button
    if frame then
        frame[1] = look.glyph(glyph)
        button = ui.stack(frame)
    else
        local props = table.clone(behaviour)
        props[1] = look.glyph(glyph)
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end

local function rounded(bytes: number): number
    if bytes <= 0 then
        return 0
    end
    local scale = 10 ^ (math.floor(math.log10(bytes)) - 2)
    return math.round(bytes / scale) * scale
end

local function fraction(used: number, total: number): number?
    return if total > 0 then math.clamp(used / total, 0, 1) else nil
end

local function uptime(seconds: number): string
    local total = math.floor(seconds)
    local days = total // 86400
    local hours = (total % 86400) // 3600
    local minutes = (total % 3600) // 60
    if days > 0 then
        return omniwm.l10n("%lldd %lldh %lldm", days, hours, minutes)
    end
    if hours > 0 then
        return omniwm.l10n("%lldh %lldm", hours, minutes)
    end
    return omniwm.l10n("%lldm", minutes)
end

local function pressureName(pressure: string): string
    if pressure == "normal" then
        return omniwm.l10n("Normal")
    end
    return if pressure == "warning" then omniwm.l10n("Warning") else omniwm.l10n("Critical")
end

local function speed(ctx: Context, bytes: number?): string
    return ctx.format.bytes(bytes or 0, "file") .. "/s"
end

local function batteryStatus(ctx: Context): string
    local power = ctx.data.power
    if power and power.charged then
        return omniwm.l10n("Fully charged")
    end
    if ctx.data.charging then
        return omniwm.l10n("Charging")
    end
    local remaining = power and power.remaining
    if not remaining then
        return "…"
    end
    return if remaining >= 60 then omniwm.l10n("%lldh %lldm", remaining // 60, remaining % 60)
        else omniwm.l10n("%lldm", remaining)
end

local function sparkline(values: { number }, width: number, height: number, top: number): string?
    if #values < 2 then
        return nil
    end
    local parts = table.create(#values)
    for index, value in values do
        local x = (index - 1) * width / (#values - 1)
        local y = height - math.clamp(value / top, 0, 1) * height
        parts[index] = string.format("%s %.2f %.2f", index == 1 and "M" or "L", x, y)
    end
    return table.concat(parts, " ")
end

local function model(ctx: Context)
    local data = ctx.data
    local system = data.system
    local thermal = data.thermal
    local cpu = data.cpu and data.cpu / 100
    local gpu = data.gpu and data.gpu / 100
    local loading = omniwm.l10n("Loading…")
    local m = {}
    m.cpu = { title = omniwm.l10n("CPU"), symbol = "cpu", value = cpu,
        detail = cpu and omniwm.l10n("Total processor") or omniwm.l10n("Waiting for delta"),
        temperature = thermal and thermal.cpu }
    m.gpu = { title = omniwm.l10n("GPU"), symbol = "cube", value = gpu,
        detail = thermal and thermal.gpuName
            or (gpu and omniwm.l10n("Device utilization") or omniwm.l10n("Unavailable")),
        temperature = thermal and thermal.gpu }
    m.memory = { title = omniwm.l10n("Memory"), symbol = "memorychip",
        value = data.memory and data.memory / 100, detail = loading }
    m.disk = { title = omniwm.l10n("Disk"), symbol = "internaldrive",
        value = data.disk and data.disk / 100, detail = loading }
    if system then
        local memory = system.memory
        m.memory.value = fraction(memory.used, memory.total)
        m.memory.detail = ctx.format.bytes(memory.used) .. " / " .. ctx.format.bytes(memory.total)
        if memory.pressure then
            m.memory.pressure = memory.pressure
            m.memory.detail ..= " · " .. pressureName(memory.pressure)
        end
        local disk = system.disk
        m.disk.value = fraction(disk.used, disk.total)
        m.disk.detail = ctx.format.bytes(disk.used, "file") .. " / " .. ctx.format.bytes(disk.total, "file")
            .. " · " .. omniwm.l10n("%@ free", ctx.format.bytes(rounded(math.max(disk.total - disk.used, 0)), "file"))
        m.host = { name = system.host.name, chip = system.host.chip, model = system.host.model, os = system.host.os,
            uptime = uptime(system.uptime) }
        m.displays = {}
        for _, display in ipairs(system.displays) do
            m.displays[#m.displays + 1] =
                omniwm.l10n("%@ @ %lld Hz", string.format("%d×%d", display.w, display.h), display.hz)
        end
        if #m.displays == 0 then
            m.displays[1] = omniwm.l10n("Display data unavailable")
        end
    end
    m.metrics = { m.cpu, m.gpu, m.memory, m.disk }
    for _, metric in m.metrics do
        metric.percent = metric.value and ctx.format.percent(metric.value) or "—"
        metric.warn = metric.value ~= nil and metric.value >= 0.9
        metric.hot = metric.temperature ~= nil and metric.temperature > 90
        metric.temperatureText = metric.temperature
            and string.format("%s°C", ctx.format.number(metric.temperature, 0)) or nil
    end
    local history = data.networkHistory
    m.network = { down = speed(ctx, data.network and data.network.down), up = speed(ctx, data.network and data.network.up),
        total = history and string.format("↓%s ↑%s", ctx.format.bytes(history.received, "file"),
            ctx.format.bytes(history.sent, "file")) or "…" }
    if history and #history.down >= 2 then
        local top = 1024
        for _, value in history.down do
            top = math.max(top, value)
        end
        for _, value in history.up do
            top = math.max(top, value)
        end
        m.network.graph = function(width: number, height: number): (string?, string?)
            return sparkline(history.down, width, height, top), sparkline(history.up, width, height, top)
        end
    end
    if data.battery then
        local level = math.clamp(data.battery / 100, 0, 1)
        m.battery = { level = level, percent = ctx.format.percent(level), charging = data.charging,
            status = batteryStatus(ctx), low = level <= 0.2 and not data.charging,
            symbol = look.batterySymbol(level * 100, data.charging) }
    end
    return m
end

local function line(symbol: string, label: string, value: string, inner: number)
    return ui.row{ w = inner, gap = 8,
        look.glyph{ name = symbol, w = 16, h = 16, color = "secondaryForeground" },
        look.text{ text = label, size = 13, grow = 1 },
        look.text{ text = value, size = 13, weight = "medium" } }
end

local function header(m, width: number)
    if not m.host then
        return look.heading(omniwm.l10n("System"), width)
    end
    return ui.row{ w = width, gap = 10,
        look.glyph{ name = "desktopcomputer", w = 24, h = 24 },
        ui.column{ gap = 3, center = false, grow = 1,
            look.text{ text = m.host.name, size = 14, weight = "semibold", maxWidth = width - 110 },
            look.text{ text = m.host.chip, size = 12, color = "secondaryForeground", maxWidth = width - 110 } },
        look.text{ text = m.host.uptime, size = 11, color = "secondaryForeground" } }
end

local function meter(metric, inner: number)
    local title = { w = inner, gap = 8,
        look.glyph{ name = metric.symbol, w = 16, h = 16, color = "secondaryForeground" },
        look.text{ text = metric.title, size = 13, grow = 1 } }
    if metric.temperatureText then
        title[#title + 1] = look.text{ text = metric.temperatureText, size = 12,
            color = metric.hot and "error" or "secondaryForeground" }
    end
    title[#title + 1] = look.text{ text = metric.percent, size = 13, weight = "medium" }
    return ui.column{ w = inner, gap = 6, center = false,
        ui.row(title),
        ui.progress{ value = metric.value or 0, w = inner, h = 4, radius = 2, fill = TRACK,
            color = if metric.warn or metric.hot then "warning" else "accent" },
        look.text{ text = metric.detail, size = 11, color = "secondaryForeground", maxWidth = inner, lines = 2 } }
end

local function metrics(m, width: number, inner: number)
    local group = { w = width, gap = 14 }
    for _, metric in m.metrics do
        group[#group + 1] = meter(metric, inner)
    end
    return look.group(group)
end

local function network(m, width: number, inner: number)
    local graph = { w = inner, h = GRAPH }
    if m.network.graph then
        local down, up = m.network.graph(inner, GRAPH)
        graph[#graph + 1] = ui.path{ d = up, w = inner, h = GRAPH, border = "secondaryForeground", borderWidth = 1.5 }
        graph[#graph + 1] = ui.path{ d = down, w = inner, h = GRAPH, border = "accent", borderWidth = 1.5 }
    else
        graph[#graph + 1] = look.text{ text = omniwm.l10n("Collecting data…"), size = 11, color = "secondaryForeground" }
    end
    return look.group{ w = width, gap = 8,
        ui.row{ w = inner, gap = 8,
            look.glyph{ name = "network", w = 16, h = 16, color = "secondaryForeground" },
            look.text{ text = omniwm.l10n("Network"), size = 13, weight = "semibold", grow = 1 } },
        ui.stack(graph),
        line("arrow.down", omniwm.l10n("Download"), m.network.down, inner),
        line("arrow.up", omniwm.l10n("Upload"), m.network.up, inner),
        line("arrow.up.arrow.down", omniwm.l10n("Total"), m.network.total, inner) }
end

local function battery(m, width: number, inner: number)
    local level = m.battery
    return look.group{ w = width, gap = 6,
        ui.row{ w = inner, gap = 8,
            look.glyph{ name = level.symbol, w = 16, h = 16,
                color = "secondaryForeground" },
            look.text{ text = omniwm.l10n("Battery"), size = 13, grow = 1 },
            look.text{ text = level.percent, size = 13, weight = "medium" } },
        ui.progress{ value = level.level, w = inner, h = 4, radius = 2, fill = TRACK,
            color = if level.low then "warning" else "accent" },
        look.text{ text = level.status, size = 11, color = "secondaryForeground", maxWidth = inner } }
end

local function details(m, width: number, inner: number)
    if not m.host then
        return look.group{ w = width,
            look.text{ text = omniwm.l10n("Loading…"), size = 13, color = "secondaryForeground" } }
    end
    local group = { w = width, gap = 4,
        look.text{ text = m.host.model, size = 13, maxWidth = inner },
        look.text{ text = m.host.os, size = 12, color = "secondaryForeground", maxWidth = inner } }
    for _, display in m.displays do
        group[#group + 1] = look.text{ text = display, size = 11, color = "secondaryForeground", maxWidth = inner }
    end
    return look.group(group)
end

local SECTIONS = {
    { "header", header },
    { "metrics", metrics },
    { "network", network },
    { "battery", battery },
    { "details", details },
}

function popout(ctx: Context)
    local m = model(ctx)
    local width = look.systemStatsWidth and look.systemStatsWidth(ctx, m) or look.panelWidth("system-stats")
    local inner = width - 24
    local props = { w = width + 32, pad = 16, gap = 12, scroll = true }
    for _, section in SECTIONS do
        local kind, default = section[1], section[2]
        if kind ~= "battery" or m.battery then
            local custom = if look.systemStatsSection then look.systemStatsSection(ctx, kind, m, width) else nil
            if custom == nil then
                props[#props + 1] = default(m, width, inner)
            elseif custom then
                props[#props + 1] = custom
            end
        end
    end
    return if look.systemStatsPanel then look.systemStatsPanel(ctx, props, m) else look.panel(ctx, props)
end
