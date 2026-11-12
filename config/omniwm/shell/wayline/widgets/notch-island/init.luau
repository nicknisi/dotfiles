-- A Dynamic Island around the MacBook notch.
-- Collapsed it hugs the notch and grows "wings" only when there's something to show (agents waiting,
-- a meeting about to start, music playing, a keep-awake timer). Hover or click to expand into now
-- playing (spinning cover, live bars, synced lyrics, controls) plus meeting/agents/awake chips. It also
-- pops open for a few seconds on a song change, a new agent needing you, or a meeting about to start.
interval = 1

local shapes = require("../lib/shapes")
local awake = require("../lib/awake")

local WING = 34
local OPEN_W = 470
local PEEK = 5 -- seconds a live moment keeps the island open
local SPRING = { response = 0.38, bounce = 0.22 }
local WHITE, DIM = "#ffffff", "#a1a1aa"
local ROBOT = "M12,2A2,2 0 0,1 14,4C14,4.74 13.6,5.39 13,5.73V7H14A7,7 0 0,1 21,14H22A1,1 0 0,1 23,15V18"
    .. "A1,1 0 0,1 22,19H21V20A2,2 0 0,1 19,22H5A2,2 0 0,1 3,20V19H2A1,1 0 0,1 1,18V15A1,1 0 0,1 2,14H3"
    .. "A7,7 0 0,1 10,7H11V5.73C10.4,5.39 10,4.74 10,4A2,2 0 0,1 12,2M7.5,13A2.5,2.5 0 0,0 5,15.5"
    .. "A2.5,2.5 0 0,0 7.5,18A2.5,2.5 0 0,0 10,15.5A2.5,2.5 0 0,0 7.5,13M16.5,13A2.5,2.5 0 0,0 14,15.5"
    .. "A2.5,2.5 0 0,0 16.5,18A2.5,2.5 0 0,0 19,15.5A2.5,2.5 0 0,0 16.5,13Z"

-- Data -------------------------------------------------------------------------------------------

local function agents(ctx)
    local raw = ctx.data.vars.agents
    if raw and ctx.state.agentsRaw ~= raw then
        ctx.state.agentsRaw, ctx.state.agents = raw, json.decode(raw)
    end
    local d = raw and ctx.state.agents
    return if d and ctx.data.seconds - d.t < 120 then d else nil
end

local function meeting(ctx)
    local cal = ctx.data.calendar
    if not cal or cal.access ~= "full" then return nil end
    local now = ctx.data.seconds
    for _, event in cal.events do
        if not event.allDay and event["end"] > now then
            local mins = math.ceil((event.start - now) / 60)
            return { id = event.id, title = event.title, color = event.color, mins = mins,
                when = if mins <= 0 then "now" else "in " .. mins .. "m" }
        end
    end
    return nil
end

local function position(media): number
    local at = media.elapsed or 0
    if media.playing then at += math.max(0, os.time() - media.sampledAt) * media.rate end
    return at
end

local function lyric(ctx, media): string?
    local lyrics = ctx.data.lyrics
    if not lyrics or lyrics.status ~= "synced" then return nil end
    local at, line = position(media), nil
    for _, entry in lyrics.lines do
        if entry.time > at then break end
        line = entry.text
    end
    return if line and line ~= "" then line else nil
end

-- Live moments: open the island for a few seconds when something new happens.
local function liveMoments(ctx, media, d, next)
    local state, now = ctx.state, ctx.data.seconds
    local song = media and (media.title .. "\0" .. media.artist)
    if song and state.song ~= nil and song ~= state.song and media.playing then state.peekUntil = now + PEEK end
    state.song = song or state.song
    local attention = d and d.attention or 0
    if attention > (state.attention or 0) then state.peekUntil = now + PEEK end
    state.attention = attention
    if next and next.mins <= 5 and next.mins > -5 and state.nudged ~= next.id then
        state.nudged, state.peekUntil = next.id, now + PEEK
    end
    return state.peekUntil ~= nil and now < state.peekUntil
end

-- Pieces --------------------------------------------------------------------------------------------

local function cover(media, size: number)
    local art = { w = size, h = size, opacity = if media.playing then 1 else 0.55,
        loop = { rotate = { 0, 360, 12 }, paused = not media.playing },
        ui.path{ d = shapes.path("Cookie12Sided"), viewBox = shapes.viewBox, w = size, h = size, mask = true },
        ui.box{ w = size, h = size, fill = "#3f3f46" } }
    art[#art + 1] = if media.artwork then ui.image{ image = media.artwork, w = size, h = size }
        else ui.symbol{ name = "music.note", size = size * 0.45, color = WHITE }
    return ui.stack(art)
end

local function bars(w: number, h: number, count: number)
    return ui.shader{ source = "island-bars.metal", audio = true, fps = 30, w = w, h = h, values = { count, 0.35, 0, 0 } }
end

local function robot(size: number, color: string)
    return ui.path{ d = ROBOT, viewBox = { 0, 0, 24, 24 }, evenOdd = true, w = size, h = size, fill = color }
end

local function control(symbol: string, command: string, size: number)
    return ui.stack{ w = size + 12, h = size + 12, radius = (size + 12) / 2, hover = "#ffffff22", onClick = command,
        pressScale = 0.85, ui.symbol{ name = symbol, size = size, color = WHITE } }
end

local function infoChip(symbol, text: string, color: string?)
    return ui.row{ gap = 6, h = 28, pad = 10, radius = 14, fill = "#ffffff14",
        symbol, ui.text{ text = text, size = 12, weight = "semibold", color = color or WHITE, maxWidth = 150 } }
end

-- Wings: what the collapsed island shows beside the notch, by priority.
local function wings(ctx, media, d, next)
    if d and d.attention > 0 then
        return robot(18, "#f5a524"), ui.text{ text = tostring(d.attention), size = 13, weight = "bold", color = "#f5a524" }
    end
    if next and next.mins <= 5 then
        return ui.box{ w = 10, h = 10, radius = 5, fill = next.color },
            ui.text{ text = next.when, size = 12, weight = "bold", color = WHITE }
    end
    if media and media.playing then
        return cover(media, 22), bars(24, 16, 5)
    end
    local left = awake.remaining(ctx)
    if left then
        return ui.symbol{ name = "cup.and.heat.waves.fill", size = 14, color = WHITE },
            ui.text{ text = left, size = 11, weight = "semibold", color = WHITE, maxWidth = WING }
    end
    return nil, nil
end

local function expanded(ctx, media, d, next, width: number)
    local rows = { w = width, gap = 12, center = false }
    if media then
        local inner = width - 64 - 12 - 120
        rows[#rows + 1] = ui.row{ w = width, gap = 12,
            cover(media, 64),
            ui.column{ gap = 3, center = false, grow = 1,
                ui.text{ text = media.title, size = 15, weight = "bold", color = WHITE, maxWidth = inner },
                ui.text{ text = media.artist, size = 13, color = DIM, maxWidth = inner },
                bars(math.min(inner, 140), 18, 14) },
            ui.row{ gap = 0,
                control("backward.fill", "media previous", 14),
                control(if media.playing then "pause.fill" else "play.fill", "media toggle", 18),
                control("forward.fill", "media next", 14) } }
        local line = lyric(ctx, media)
        if line then
            rows[#rows + 1] = ui.text{ key = "lyric", text = "♪ " .. line, size = 14, weight = "semibold", color = WHITE,
                maxWidth = width, marquee = true, appear = { opacity = 0, dy = 6, animate = SPRING } }
        end
    end
    local chips = { gap = 8 }
    if next then
        chips[#chips + 1] = infoChip(ui.box{ w = 8, h = 8, radius = 4, fill = next.color }, next.title .. " · " .. next.when)
    end
    if d then
        local text = d.total .. " agents" .. (if d.attention > 0 then " · " .. d.attention .. " need you" else "")
        chips[#chips + 1] = infoChip(robot(14, if d.attention > 0 then "#f5a524" else WHITE), text)
    end
    if awake.on(ctx) then
        chips[#chips + 1] = infoChip(ui.symbol{ name = "cup.and.heat.waves.fill", size = 12, color = WHITE },
            awake.remaining(ctx) or "awake")
    end
    if #chips > 0 then rows[#rows + 1] = ui.row(chips) end
    return ui.column(rows)
end

-- Root ------------------------------------------------------------------------------------------------

function render(ctx)
    local island = ctx.data.island
    if not island or not island.notch then return ui.box{ w = 0, h = 0 } end
    local notch = island.notch
    local media = ctx.data.media
    if media and media.title == "" then media = nil end
    local d, next = agents(ctx), meeting(ctx)
    local peeking = liveMoments(ctx, media, d, next)
    local open = ctx.state.open or ctx.state.hover or peeking
    local left, right = wings(ctx, media, d, next)

    local capsule = { key = "capsule", align = "top", radius = notch.h / 2, fill = "#000000", animate = SPRING,
        onClick = function(c) c.state.open = not c.state.open end,
        onOutsidePress = function(c) c.state.open = false end,
        onHover = function(c, event) c.state.hover = event.phase == "began" end, hoverDelay = 0.25, hoverGrace = 0.35 }
    if open then
        local content = expanded(ctx, media, d, next, OPEN_W - 36)
        capsule.w, capsule.radius, capsule.pad = OPEN_W, 30, 18
        capsule[1] = ui.column{ gap = 0, center = false, ui.box{ w = 1, h = notch.h - 10 }, content }
    elseif left then
        capsule.w, capsule.h = notch.w + 2 * WING, notch.h
        capsule[1] = ui.row{ w = notch.w + 2 * WING, h = notch.h,
            ui.stack{ w = WING, h = notch.h, left }, ui.box{ w = notch.w, h = 1 }, ui.stack{ w = WING, h = notch.h, right } }
    else
        capsule.w, capsule.h = notch.w, notch.h -- nothing to show: just the notch
    end
    -- align/dx only position children inside a stack; centre the capsule on the notch, hugging the top edge.
    capsule.dx = notch.x + notch.w / 2 - island.size.w / 2
    return ui.stack{ w = island.size.w, h = island.size.h, ui.box(capsule) }
end
