-- Prairie: a little scene for the bar, just for fun. A pixel cat reacts to the machine (naps when idle, sits up under load, gets the zoomies when it's busy, fans itself when the CPU
-- runs hot), ducks out of sight while your camera is on, and perks up with a "!" when a coding agent needs you
-- (and wiggles when they're all handled). A tiny dancer bobs to the beat while music plays, and about once an
-- hour a bird or a UFO drifts by. Click to pet the cat. Calendar extras: a party hat after 5pm on Fridays, a
-- pumpkin in October, snow in December.
interval = 10

local look = require("../lib/look")

local MONO = "Monaspace Neon"
local INK = look.ink -- a look that prints everything in one ink (Bridge's black on console segments)

-- Pixel cat (viewBox 10x8, evenOdd: the eyes are holes). Sitting faces you with its tail drawn separately
-- so it can wag; the loaf is curled up asleep.
local SIT = "M1 0h1v1H1z M5 0h1v1H5z M1 1h5v3H1z M1 4h6v4H1z M2 2h1v1H2z M4 2h1v1H4z"
local TAIL = "M0 3h2v1H0z M2 0h1v4H2z" -- viewBox 3x5
local PEEK = "M1 4h1v1H1z M5 4h1v1H5z M1 5h5v3H1z M2 6h1v1H2z M4 6h1v1H4z" -- just ears and eyes over the edge
local LOAF = "M0 2h1v1H0z M3 2h1v1H3z M0 3h4v5H0z M4 4h5v4H4z M9 6h1v2H9z M0.6 5h1v0.5h-1z M2.4 5h1v0.5h-1z"
local HAT = "M2 0L4 4H0Z" -- viewBox 4x4
local PUMPKIN = "M3.5 0h1v2h-1z M1 2h6v5H1z M0 3h1v3H0z M7 3h1v3H7z M3 3h0.5v3H3z M4.5 3h0.5v3h-0.5z" -- viewBox 8x7
local DANCER = "M1.5 0h2v2h-2z M0 1h1v1H0z M1 2h1v1H1z M4 1h1v1H4z M3 2h1v1H3z M2 2h1v3H2z M1 5h3v1H1z"
    .. " M1 6h1v2H1z M3 6h1v2H3z" -- viewBox 5x8, arms up
local BIRD = "M0 0h1v1H0z M1 1h1v1H1z M2 2h1v1H2z M3 1h1v1H3z M4 0h1v1H4z" -- viewBox 5x3
local UFO = "M2 0h3v2H2z M0 2h7v1H0z M1 3h5v1H1z" -- viewBox 7x4

-- where the party hat sits on each pose (viewBox units): head centre x, top of head y
local HEAD = { asleep = { 2, 2 }, peek = { 3.5, 4 } }

-- Motion: a pulse plays once per key, so keying it to the 30s render window chains it into continuous
-- motion (same trick as the agents widget). Eased at both ends so the seam doesn't jump.
local function wave(fn: (number) -> number, samples: number): { number }
    local out = {}
    for i = 0, samples do
        local t = i / samples * 30
        out[i + 1] = fn(t) * math.min(1, t / 0.5, (30 - t) / 0.5)
    end
    out[#out] = 0 -- pulses must end exactly at zero
    return out
end

local WAG = wave(function(t) return math.sin(t / 1.5 * math.pi) * 18 end, 240)
local HOP = wave(function(t) return -math.abs(math.sin(t / 0.6 * math.pi)) * 2 end, 240)
local PET = { 0, -14, 14, -10, 10, -5, 0 }

local DANCES = {}
local function dance(bpm: number)
    if not DANCES[bpm] then
        local beat = 60 / bpm
        -- two keyframes per beat (down, up) lands exactly on half-beats and stays under the 256-entry pulse cap
        local samples = bpm
        DANCES[bpm] = {
            dy = wave(function(t) return -math.abs(math.sin(t / beat * math.pi)) * 2 end, samples),
            rotate = wave(function(t) return math.sin(t / beat * math.pi) * 12 end, samples),
        }
    end
    return DANCES[bpm]
end

local function snow(s: number, h: number)
    local flakes = {}
    for i, spot in { { -7, 3.1 }, { -2, 4.3 }, { 3, 2.6 }, { 7, 3.7 } } do
        flakes[i] = ui.box{ align = "top", dx = spot[1] * s, w = 1.6 * s, h = 1.6 * s, radius = s,
            fill = INK or "foreground/0.8", loop = { dy = { -2 * s, h, spot[2] } } }
    end
    return flakes
end

-- How many coding agents are waiting on you, from the agents widget's feed (nil when it's stale or missing).
local function attention(ctx): number?
    local raw = ctx.data.vars.agents
    if not raw then return nil end
    if ctx.state.raw ~= raw then
        local ok, decoded = pcall(json.decode, raw)
        ctx.state.raw, ctx.state.crew = raw, if ok then decoded else nil
    end
    local crew = ctx.state.crew
    if type(crew) ~= "table" or ctx.data.seconds - (crew.t or 0) >= 120 then return nil end
    return crew.attention or 0
end

-- poses: asleep, awake, zoomies, alert (an agent needs you), peek (camera's on)
local function cat(ctx, pose: string, partying: boolean, size: number, window: number)
    local unit = size / 10
    local asleep = pose == "asleep"
    local color = INK or (if asleep then "mutedForeground" else "foreground")
    local body = ui.path{ w = size, h = 8 * unit, viewBox = { 0, 0, 10, 8 }, evenOdd = true,
        d = if asleep then LOAF elseif pose == "peek" then PEEK else SIT, fill = color }
    local hops = pose == "zoomies" or pose == "alert"
    local scene = { w = size, h = 8 * unit, body,
        pulse = if hops then { key = "hop" .. window, duration = 30, dy = HOP } else nil }
    if asleep then
        scene[#scene + 1] = ui.text{ text = "z", font = MONO, size = size * 0.45, weight = "bold", color = "mutedForeground",
            align = "topTrailing", dy = -size * 0.2, loop = { dy = { 1, -size * 0.35, 2.4 } } }
    elseif pose ~= "peek" then
        scene[#scene + 1] = ui.path{ align = "bottomTrailing", w = 3 * unit, h = 5 * unit, viewBox = { 0, 0, 3, 5 },
            d = TAIL, fill = color, pulse = { key = "wag" .. window, duration = 30, rotate = WAG } }
    end
    if pose == "alert" then
        scene[#scene + 1] = ui.text{ text = "!", font = MONO, size = size * 0.6, weight = "bold", color = INK or "warning",
            align = "topTrailing", dx = size * 0.15, dy = -size * 0.35 }
    end
    if partying then
        local head = HEAD[pose] or { 3.5, 0 }
        local headX, headTop = head[1], head[2]
        scene[#scene + 1] = ui.path{ align = "top", w = 3 * unit, h = 3 * unit, viewBox = { 0, 0, 4, 4 }, d = HAT,
            fill = INK or "purple", dx = (headX - 5) * unit, dy = (headTop - 2.5) * unit }
    end
    -- Petting wiggles the whole cat once; the outer stack keeps it separate from the hop.
    local petted = ctx.state.petted
    return ui.stack{ w = size, h = 8 * unit, ui.stack(scene),
        pulse = if petted then { key = "pet" .. petted, duration = 0.8, rotate = PET } else nil }
end

function render(ctx)
    local data = ctx.data
    local s = data.bar.style.height / 40
    local now = os.date("*t")
    local window = math.floor(data.seconds / 30)

    local cpu = data.cpu or 0
    local temp = data.thermal and data.thermal.cpu
    local hot = temp ~= nil and temp > 90 -- same line as the built-in system-stats widget
    local waiting = attention(ctx)
    if waiting then
        -- everyone who needed you got handled: happy wiggle (same moment the agents widget says "vibes: immaculate")
        if (ctx.state.lastWaiting or 0) > 0 and waiting == 0 then ctx.state.petted = os.time() end
        ctx.state.lastWaiting = waiting
    end
    local camera = data.privacy and data.privacy.camera

    local pose = if camera then "peek"
        elseif waiting and waiting > 0 then "alert"
        elseif hot or cpu >= 60 then "zoomies" elseif cpu >= 20 then "awake" else "asleep"
    local partying = now.wday == 6 and now.hour >= 17
    local help = if camera then "camera-shy (your camera's on)"
        elseif pose == "alert" then string.format("%d agent%s need%s you", waiting, if waiting == 1 then "" else "s",
            if waiting == 1 then "s" else "")
        elseif hot then string.format("too hot! cpu at %.0f°C", temp)
        elseif pose == "zoomies" then string.format("zoomies (cpu %.0f%%)", cpu)
        elseif pose == "awake" then string.format("keeping an eye on things (cpu %.0f%%)", cpu)
        else "napping"
    if partying then help ..= " · it's Friday!" end

    local size = 14 * s
    local overlay = { cat(ctx, pose, partying, size, window) }
    if now.month == 12 then -- snow falls on the cat
        for _, flake in snow(s, size) do overlay[#overlay + 1] = flake end
    end
    -- Rare visitor: each 5-minute slot has a 1-in-12 chance (a fixed hash of the slot), and the visit is that
    -- slot's first 30s. shortcut: it just vanishes when the 30s are up, even mid-flight; fine for a cameo.
    local slot = math.floor(data.seconds / 300)
    local roll = math.sin(slot * 12.9898) * 43758.5453
    if roll - math.floor(roll) < 1 / 12 and data.seconds % 300 < 30 then
        local ufo = slot % 2 == 0
        overlay[#overlay + 1] = ui.path{ align = "top", dy = -size * 0.45,
            w = (if ufo then 8 else 6) * s, h = (if ufo then 4.5 else 3.5) * s,
            viewBox = if ufo then { 0, 0, 7, 4 } else { 0, 0, 5, 3 }, d = if ufo then UFO else BIRD,
            fill = INK or (if ufo then "green" else "foreground"), loop = { dx = { 40 * s, -40 * s, 10 } } }
        help ..= if ufo then " · was that a UFO?" else " · a bird flew by"
    end
    local kitty = if #overlay > 1 then ui.stack(overlay) else overlay[1]
    local row = { gap = 5 * s, pad = 9 * s, h = 28 * s, radius = 14 * s, help = help .. " · click to pet",
        onClick = function(c) c.state.petted = os.time() end, kitty }
    if hot then
        row[#row + 1] = ui.symbol{ name = "fan.fill", size = 9 * s, color = INK or "cyan", loop = { rotate = { 0, 360, 0.6 } } }
    end
    if now.month == 10 then
        row[#row + 1] = ui.path{ w = 9 * s, h = 8 * s, viewBox = { 0, 0, 8, 7 }, evenOdd = true, d = PUMPKIN,
            fill = INK or "orange" }
    end

    local media = data.media
    if media and media.playing then
        local bpm = math.floor(math.clamp(data.tempo or 112, 60, 180) + 0.5)
        local moves = dance(bpm)
        row[#row + 1] = ui.path{ w = 6 * s, h = 10 * s, viewBox = { 0, 0, 5, 8 }, d = DANCER, fill = INK or "accent",
            pulse = { key = "dance" .. bpm .. "-" .. window, duration = 30, dy = moves.dy, rotate = moves.rotate } }
        row.help ..= string.format(" · dancing to %s", media.title)
    end

    -- No pill: the scene sits right on the bar. Only a one-ink look (Bridge) keeps its pill, since the ink needs
    -- that segment behind it to show up.
    if INK and look.pill then look.pill(row, ctx) end
    return ui.row(row)
end
