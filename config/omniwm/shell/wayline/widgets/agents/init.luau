-- The Crew: one pixel bot per running coding agent (tmux, Riker, Rex, quake, terminals). Bots bob while
-- working, sleep when idle and wave when they need you; Riker's workers wear the captain's hat.
-- The popout lists the crew with today's spend. Data is pushed by bin/omniwm-agents via
-- `omniwmctl shell set agents <json>`.
interval = 5 -- short, so the "vibes" flash clears after a few seconds

local look = require("../lib/look")
local chip = require("../lib/chip")

local STALE = 120 -- seconds without a push before the count shows "?"
local MAX_CREW = 8 -- bots shown in the bar; the rest become "+N"
local MONO = "Monaspace Neon" -- bundled in shell/fonts (OmniWM only loads fonts from fonts/ folders)

-- 8x8 pixel bots (evenOdd: the eyes are holes in the body). Awake bots have an antenna; Riker's workers
-- wear a captain's hat instead; sleeping bots have closed eyes.
local BODY = "M1 2.4H7V7.4H1Z"
local ANTENNA = "M3.5 0.6H4.5V2.4H3.5Z"
local HAT = "M1.2 1.7H6.8V2.4H1.2Z M2.4 0.4H5.6V1.7H2.4Z"
local OPEN = "M2.2 3.7H3.3V4.8H2.2Z M4.7 3.7H5.8V4.8H4.7Z"
local SHUT = "M2.1 4.5H3.4V5H2.1Z M4.6 4.5H5.9V5H4.6Z"

local PANEL = 340
local INNER = PANEL - 24 -- wayline's titled panel pads its body by 12
local ROW = INNER - 24 -- look.group pads by 12

local function data(ctx)
    local raw = ctx.data.vars.agents
    if raw and ctx.state.raw ~= raw then
        ctx.state.raw, ctx.state.data = raw, json.decode(raw)
    end
    return if raw then ctx.state.data else nil
end

local function money(value: number): string
    return if value >= 10 then string.format("$%.0f", value) else string.format("$%.2f", value)
end

-- Motion: a pulse plays once per key, so keying it to the 30s render window chains them into continuous
-- motion. Bobs are staggered per bot (four phases) and eased in/out so the 30s seam doesn't jump.
local BOBS, WIGGLE = {}, {}
for phase = 1, 4 do
    local bob = {}
    for i = 0, 240 do
        local t = i / 240 * 30
        local ease = math.min(1, t / 0.5, (30 - t) / 0.5)
        bob[i + 1] = math.sin((t + phase * 0.45) * math.pi) * 1.4 * ease
    end
    bob[#bob] = 0 -- pulses must end exactly at zero
    BOBS[phase] = bob
end
for i = 0, 240 do
    local t = i / 240 * 30
    local beat = t % 4 -- wave for the first 0.9s of every 4s
    WIGGLE[i + 1] = if beat < 0.9 then math.sin(beat / 0.9 * 4 * math.pi) * 16 else 0
end
WIGGLE[#WIGGLE] = 0

local function mood(a): string
    if a.attention then return "waving" end
    if a.state == "busy" or a.state == "running" then return "busy" end
    return "asleep"
end

local MOOD_COLOR = { waving = "warning", busy = "accent", asleep = "mutedForeground" }

local function bot(a, size: number, index: number, key: number)
    local m = mood(a)
    local d = BODY .. " " .. (if a.host == "riker" then HAT else ANTENNA) .. " " .. (if m == "asleep" then SHUT else OPEN)
    local pulse = if m == "waving" then { key = "wave" .. key, duration = 30, rotate = WIGGLE }
        elseif m == "busy" then { key = "bob" .. index .. "-" .. key, duration = 30, dy = BOBS[(index - 1) % 4 + 1] }
        else nil
    local glyph = ui.path{ w = size, h = size, viewBox = { 0, 0, 8, 8 }, evenOdd = true, d = d, fill = MOOD_COLOR[m],
        pulse = pulse }
    if m ~= "asleep" then return glyph end
    return ui.stack{ w = size, h = size, glyph,
        ui.text{ text = "z", font = MONO, size = size * 0.42, weight = "bold", color = "mutedForeground", align = "topTrailing",
            dx = size * 0.25, dy = -size * 0.15, loop = { dy = { 1, -size * 0.35, 2.4 } } } }
end

-- Easter egg from the old sketchybar pill: when the last agent waiting on you is handled, flash
-- "vibes: immaculate" for a few seconds.
local function vibes(ctx, d): boolean
    local state, now = ctx.state, ctx.data.seconds
    if (state.lastAttention or 0) > 0 and d.attention == 0 then
        state.vibesUntil = now + 4
    end
    state.lastAttention = d.attention
    return state.vibesUntil ~= nil and now < state.vibesUntil
end

function render(ctx)
    local d = data(ctx)
    local fresh = d and ctx.data.seconds - d.t < STALE
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local button
    if fresh and vibes(ctx, d) then
        button = chip(ctx, ui.symbol{ name = "checkmark", size = size * 0.5, weight = "bold", color = "accentForeground",
            pulse = { key = "vibes" .. ctx.state.vibesUntil, duration = 0.5, scale = { 0.6, -0.15, 0.08, 0 } } },
            "success", "vibes: immaculate")
    else
        local pill = { gap = 5 * scale, pad = 8 * scale, h = size, radius = math.floor(size * 0.24),
            fill = "elevatedSurface", hoverOpacity = 0.9,
            border = if fresh and d.attention > 0 then "warning" else nil, borderWidth = 1.5 }
        local b = 15 * scale
        if not fresh then
            pill[#pill + 1] = bot({ state = "idle" }, b, 1, 0)
            pill[#pill + 1] = ui.text{ text = "?", font = MONO, size = 13 * scale, color = "mutedForeground" }
        else
            local key = math.floor(ctx.data.seconds / 30)
            for i, a in d.agents do
                if i > MAX_CREW then break end
                pill[#pill + 1] = bot(a, b, i, key)
            end
            if d.total > MAX_CREW then
                pill[#pill + 1] = ui.text{ text = "+" .. (d.total - MAX_CREW), font = MONO, size = 12 * scale,
                    weight = "semibold", color = "secondaryForeground" }
            elseif d.total == 0 then
                pill[#pill + 1] = ui.text{ text = "no crew", font = MONO, size = 12 * scale, color = "mutedForeground" }
            end
        end
        button = if style.vertical then ui.column(pill) else ui.row(pill)
    end
    button.onClick = ui.popout
    button.help = if not fresh then "omniwm-agents isn't pushing (see its LaunchAgent log)"
        elseif d.attention > 0 then d.attention .. " need you" else d.total .. " agents"
    return button
end

local function line(left: string, right: string, color: string?)
    return ui.row{ w = ROW,
        look.text{ text = left, size = 12, color = color or "secondaryForeground", grow = 1, maxWidth = ROW - 90 },
        look.text{ text = right, size = 12, weight = "medium" } }
end

local function badge(a)
    local m = mood(a)
    local text, color = "CREW", "accent"
    if a.host == "riker" then text, color = "CAPT", "warning" end
    if m == "asleep" then text, color = "OFF", "mutedForeground" end
    return ui.row{ h = 16, pad = 4, radius = 4, border = color, borderWidth = 1,
        ui.text{ text = text, font = MONO, size = 9, weight = "bold", color = color } }
end

local function agentRow(a, index: number, key: number)
    local meta = a.kind .. " · " .. a.host .. (if a.where ~= "" then " · " .. a.where else "") .. " · " .. a.age
    local m = mood(a)
    local status = if m == "waving" then "waving at you" elseif m == "busy" then "typing…" else "asleep"
    return ui.row{ w = ROW, gap = 8,
        bot(a, 14, index, key),
        ui.column{ gap = 2, center = false, grow = 1,
            ui.row{ gap = 6, badge(a),
                look.text{ text = if a.label ~= "" then a.label else a.kind, size = 13, weight = "medium",
                    maxWidth = ROW - 130 } },
            look.text{ text = meta, size = 11, color = "secondaryForeground", maxWidth = ROW - 40 } },
        look.text{ text = status, size = 11, weight = "semibold", color = MOOD_COLOR[m] } }
end

function popout(ctx)
    local d = data(ctx)
    if not d then
        return look.panel(ctx, { look.text{ text = "No agent data yet. Is bin/omniwm-agents --watch running?",
            size = 13, color = "secondaryForeground", maxWidth = INNER } })
    end
    local rows = { w = PANEL }
    local summary = d.total .. " running"
    if d.attention > 0 then
        summary ..= " · " .. d.attention .. " need you"
    end
    if d.subagents > 0 then
        summary ..= " · " .. d.subagents .. " subagents"
    end
    rows[1] = ui.row{ w = INNER, gap = 8,
        bot({ state = "busy" }, 15, 1, 0),
        ui.text{ text = "The Crew", size = 14, weight = "bold", grow = 1 },
        look.text{ text = summary, size = 12, color = "secondaryForeground" } }

    local where = {}
    for host, count in d.hosts do
        where[#where + 1] = host .. " " .. count
    end
    table.sort(where)
    local overview = { w = INNER, fill = "elevatedSurface" }
    if #where > 0 then
        overview[#overview + 1] = line("Where", table.concat(where, " · "))
    end
    if d.spend then
        overview[#overview + 1] = line("Spend today (" .. d.spend.sessions .. " sessions)", money(d.spend.today), "foreground")
        for _, tool in d.spend.tools do
            overview[#overview + 1] = line("  " .. tool[1], money(tool[2]))
        end
        for i, model in d.spend.models do
            if i > 3 then break end
            overview[#overview + 1] = line("  " .. model[1], money(model[2]))
        end
    end
    if d.claude5h then
        local reset = ""
        if d.claude5h.resets and d.claude5h.resets > ctx.data.seconds then
            local mins = math.floor((d.claude5h.resets - ctx.data.seconds) / 60)
            reset = string.format(" · resets in %dh%02dm", mins // 60, mins % 60)
        end
        overview[#overview + 1] = line("Claude 5h window", d.claude5h.used .. "%" .. reset,
            if d.claude5h.used >= 85 then "warning" else nil)
    end
    rows[#rows + 1] = look.group(overview)

    local list = { w = INNER, gap = 10, fill = "elevatedSurface" }
    local key = math.floor(ctx.data.seconds / 30)
    for i, a in d.agents do
        list[#list + 1] = agentRow(a, i, key)
    end
    if #d.agents == 0 then
        list[#list + 1] = look.text{ text = "Nothing running", size = 13, color = "secondaryForeground" }
    elseif d.total > #d.agents then
        list[#list + 1] = look.text{ text = "+" .. (d.total - #d.agents) .. " more", size = 12,
            color = "secondaryForeground" }
    end
    rows[#rows + 1] = look.group(list)

    local age = ctx.data.seconds - d.t
    if age >= STALE then
        rows[#rows + 1] = look.text{ text = string.format("Last update %d min ago", age // 60), size = 11,
            color = "warning" }
    end
    return look.panel(ctx, rows)
end
