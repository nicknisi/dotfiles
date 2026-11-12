-- Running coding agents (tmux, Riker, Rex, quake, terminals) with today's spend.
-- Data is pushed by bin/omniwm-agents via `omniwmctl shell set agents <json>`.
interval = 30

local look = require("../lib/look")
local chip = require("../lib/chip")

local STALE = 120 -- seconds without a push before the count shows "?"
-- Material Design "robot" (the old sketchybar nf-md-robot glyph) as a vector path:
-- nerd-font text gets clipped by OmniWM's text layout.
local ROBOT = "M12,2A2,2 0 0,1 14,4C14,4.74 13.6,5.39 13,5.73V7H14A7,7 0 0,1 21,14H22A1,1 0 0,1 23,15V18"
    .. "A1,1 0 0,1 22,19H21V20A2,2 0 0,1 19,22H5A2,2 0 0,1 3,20V19H2A1,1 0 0,1 1,18V15A1,1 0 0,1 2,14H3"
    .. "A7,7 0 0,1 10,7H11V5.73C10.4,5.39 10,4.74 10,4A2,2 0 0,1 12,2M7.5,13A2.5,2.5 0 0,0 5,15.5"
    .. "A2.5,2.5 0 0,0 7.5,18A2.5,2.5 0 0,0 10,15.5A2.5,2.5 0 0,0 7.5,13M16.5,13A2.5,2.5 0 0,0 14,15.5"
    .. "A2.5,2.5 0 0,0 16.5,18A2.5,2.5 0 0,0 19,15.5A2.5,2.5 0 0,0 16.5,13Z"

local function robot(size: number)
    return ui.path{ w = size, h = size, viewBox = { 0, 0, 24, 24 }, fill = "accent", evenOdd = true, d = ROBOT }
end

local PANEL = 340
local INNER = PANEL - 24 -- wayline's titled panel pads its body by 12
local ROW = INNER - 24 -- look.group pads by 12
local STATE_COLOR = { question = "purple", waiting = "warning", permit = "warning", done = "success",
    busy = "accent", running = "accent", idle = "mutedForeground" }

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

-- The robot is alive: it bobs while agents work and wiggles when one needs you. A pulse plays once per
-- key, so keying it to the 30s render interval chains them into continuous motion.
local BOB, WIGGLE = {}, {}
for i = 0, 240 do
    local t = i / 240 * 30 -- seconds into the 30s pulse
    BOB[i + 1] = math.sin(t * math.pi) * 1.5 -- 2s period, 15 full bobs, ends at zero
    local phase = t % 5 -- wiggle for the first 0.8s of every 5s
    WIGGLE[i + 1] = if phase < 0.8 then math.sin(phase / 0.8 * 4 * math.pi) * 14 else 0
end
BOB[#BOB], WIGGLE[#WIGGLE] = 0, 0 -- pulses must end exactly at zero

local function alive(ctx, d)
    local busy = false
    for _, a in d.agents do
        if a.state == "busy" or a.state == "running" then busy = true end
    end
    local key = math.floor(ctx.data.seconds / 30)
    if d.attention > 0 then return { key = "wiggle" .. key, duration = 30, rotate = WIGGLE } end
    if busy then return { key = "bob" .. key, duration = 30, dy = BOB } end
    return nil
end

function render(ctx)
    local d = data(ctx)
    local fresh = d and ctx.data.seconds - d.t < STALE
    local size = 32 * ctx.data.bar.style.height / 40
    local hue = if not fresh then "elevatedSurface" elseif d.attention > 0 then "warning" else "accent"
    local glyph = ui.path{ w = size * 0.56, h = size * 0.56, viewBox = { 0, 0, 24, 24 }, evenOdd = true, d = ROBOT,
        fill = if fresh then "accentForeground" else "secondaryForeground", pulse = fresh and alive(ctx, d) or nil }
    local button = chip(ctx, glyph, hue, if fresh then tostring(d.total) else "?",
        if fresh then hue else "secondaryForeground")
    button.onClick = ui.popout
    button.help = if not fresh then "omniwm-agents isn't pushing (see its LaunchAgent log)"
        elseif d.attention > 0 then d.attention .. " need you" else nil
    return button
end

local function line(left: string, right: string, color: string?)
    return ui.row{ w = ROW,
        look.text{ text = left, size = 12, color = color or "secondaryForeground", grow = 1, maxWidth = ROW - 90 },
        look.text{ text = right, size = 12, weight = "medium" } }
end

local function agentRow(a)
    local meta = a.kind .. " · " .. a.host .. (if a.where ~= "" then " · " .. a.where else "") .. " · " .. a.age
    return ui.row{ w = ROW, gap = 8,
        ui.box{ w = 7, h = 7, radius = 3.5, fill = STATE_COLOR[a.state] or "secondaryForeground" },
        ui.column{ gap = 2, center = false, grow = 1,
            look.text{ text = if a.label ~= "" then a.label else a.kind, size = 13, weight = "medium",
                maxWidth = ROW - 75 },
            look.text{ text = meta, size = 11, color = "secondaryForeground", maxWidth = ROW - 75 } },
        look.text{ text = a.state, size = 11, weight = "semibold", color = STATE_COLOR[a.state] or "secondaryForeground" } }
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
        robot(15),
        ui.text{ text = "Agents", size = 14, weight = "bold", grow = 1 },
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
    for _, a in d.agents do
        list[#list + 1] = agentRow(a)
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
