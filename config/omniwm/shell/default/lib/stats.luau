-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")

local stats = {}
local SAMPLES = 30
local RING = "M12 2.5 A9.5 9.5 0 1 1 12 21.5 A9.5 9.5 0 1 1 12 2.5"

local function history(ctx, key: string): { number }
    local all = ctx.state.history
    if not all then
        all = { cpu = {}, memory = {} }
        ctx.state.history = all
    end
    local cpu = ctx.data.cpu
    if cpu and all.sampled ~= cpu then
        all.sampled = cpu
        for name, value in { cpu = cpu, memory = ctx.data.memory } do
            local list = all[name]
            list[#list + 1] = value
            if #list > SAMPLES then
                table.remove(list, 1)
            end
        end
    end
    return all[key]
end

local function arc(fraction: number): string
    if fraction >= 0.999 then
        return RING
    end
    local angle = fraction * 2 * math.pi
    return string.format("M12 2.5 A9.5 9.5 0 %d 1 %.2f %.2f", if angle > math.pi then 1 else 0,
        12 + 9.5 * math.sin(angle), 12 - 9.5 * math.cos(angle))
end

function stats.gauge(value: number, size: number, color: string, center)
    local ring = { w = size, h = size,
        ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = RING, border = "foreground/0.16",
            borderWidth = 2.6 } }
    if value > 0.5 then
        ring[#ring + 1] = ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, d = arc(value / 100),
            border = color, borderWidth = 2.6, animate = "ease" }
    end
    ring[#ring + 1] = center
    return ui.stack(ring)
end

function stats.sparkline(values: { number }, w: number, h: number, color: string)
    if #values < 2 then
        return ui.box{ w = w, h = h }
    end
    local last = #values - 1
    local line = {}
    for index, value in values do
        line[#line + 1] = string.format("%s%d %.1f", if index == 1 then "M" else "L", index - 1, 100 - value)
    end
    local stroke = table.concat(line, " ")
    return ui.stack{ w = w, h = h,
        ui.path{ w = w, h = h, viewBox = { 0, -4, last, 108 },
            d = stroke .. string.format(" L%d 104 L0 104 Z", last), fill = color .. "/0.1" },
        ui.path{ w = w, h = h, viewBox = { 0, -4, last, 108 }, d = stroke, border = color, borderWidth = 1.4 } }
end

local function meter(ctx, graph: boolean, key: string, symbol: string, value: number?)
    return { key = key, symbol = symbol, value = value or 0, available = value ~= nil, hot = value ~= nil and value >= 90,
        history = if graph then history(ctx, key) else nil }
end

function stats.state(ctx)
    local variant = (ctx.data.settings or {}).variant or "meters"
    local graph = variant == "graph"
    return { variant = variant, meters = {
        meter(ctx, graph, "cpu", "cpu", ctx.data.cpu),
        meter(ctx, graph, "memory", "memorychip", ctx.data.memory),
    } }
end

local function rate(ctx, bytes: number): string
    return ctx.format.bytes(bytes, "file") .. "/s"
end

function stats.model(ctx)
    local data = ctx.data
    local graph = (data.settings or {}).variant == "graph"
    local rows = {}
    local function usage(key: string, symbol: string, label: string, value: number?, sampled: boolean)
        rows[#rows + 1] = { key = key, symbol = symbol, label = label, value = value, hot = value ~= nil and value >= 90,
            text = if value then ctx.format.percent(value / 100) else "—",
            history = if graph and sampled then history(ctx, key) else nil }
    end
    usage("cpu", "cpu", omniwm.l10n("CPU"), data.cpu, true)
    usage("memory", "memorychip", omniwm.l10n("Memory"), data.memory, true)
    if data.gpu then
        usage("gpu", "cube", omniwm.l10n("GPU"), data.gpu, false)
    end
    if data.disk then
        usage("disk", "internaldrive", omniwm.l10n("Disk"), data.disk, false)
    end
    if data.network then
        rows[#rows + 1] = { key = "down", symbol = "arrow.down", label = omniwm.l10n("Download"),
            text = rate(ctx, data.network.down) }
        rows[#rows + 1] = { key = "up", symbol = "arrow.up", label = omniwm.l10n("Upload"),
            text = rate(ctx, data.network.up) }
    end
    return { graph = graph, rows = rows }
end

function stats.content(ctx, width: number?, m)
    width = width or look.width
    m = m or stats.model(ctx)
    local rows = { w = width, gap = 12 }
    for _, row in m.rows do
        rows[#rows + 1] = ui.row{ w = width - 24, gap = 8,
            look.glyph{ name = row.symbol, w = 16, h = 16, color = "secondaryForeground" },
            look.text{ text = row.label, size = 13, grow = 1 },
            look.text{ text = row.text, size = 13, reserve = "000.0 MB/s" },
            if row.history then stats.sparkline(row.history, 80, 18, "accent")
                elseif m.graph then ui.box{ w = 80, h = 18 } else nil }
    end
    return ui.column{ w = width, gap = 12, center = false,
        look.heading(omniwm.l10n("System")),
        look.group(rows) }
end

function stats.popout(ctx)
    local m = stats.model(ctx)
    return look.statsPanel and look.statsPanel(ctx, m)
        or look.panel(ctx, { w = look.width + 28, stats.content(ctx, nil, m) })
end

return table.freeze(stats)
