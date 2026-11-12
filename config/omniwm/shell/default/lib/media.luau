-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")

local media = {}
local LYRIC_LINES = 2
local TOGGLE = "media toggle"

local function clock(seconds: number): string
    local total = math.max(0, math.floor(seconds))
    local hours, minutes, rest = total // 3600, total % 3600 // 60, total % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, rest)
    end
    return string.format("%d:%02d", minutes, rest)
end

local function seek(time: number): string
    return string.format("media seek %.1f", time)
end

function media.state(ctx)
    local title = ctx.select("media", "title")
    if not title or title == "" then
        return nil
    end
    local artist = ctx.select("media", "artist")
    local playing = ctx.select("media", "playing") == true
    return { title = title, artist = artist, playing = playing, toggle = TOGGLE,
        symbol = if playing then "play.fill" else "pause.fill",
        help = if artist and artist ~= "" then title .. " — " .. artist else title }
end

local function lyrics(ctx, position: number)
    local data = ctx.data.lyrics
    if not data then
        return nil
    end
    local result = { status = data.status, access = data.access, seek = seek }
    if data.access == "off" or data.access == "blocked" then
        result.message = if data.access == "off" then omniwm.l10n("Turned off in Settings")
            else omniwm.l10n("Blocked by your organization")
        return result
    end
    if data.status ~= "synced" or #data.lines == 0 then
        result.message = if data.status == "loading" then omniwm.l10n("Loading lyrics…") else omniwm.l10n("No lyrics found")
        return result
    end
    local current = 1
    for index, entry in data.lines do
        if entry.time > position then
            break
        end
        current = index
    end
    result.current = current
    result.lines = data.lines
    result.visible = {}
    for index = math.max(1, current - LYRIC_LINES), math.min(#data.lines, current + LYRIC_LINES) do
        local entry = data.lines[index]
        result.visible[#result.visible + 1] = { text = if entry.text ~= "" then entry.text else "…",
            current = index == current, seek = seek(entry.time) }
    end
    return result
end

function media.model(ctx, compact: boolean?, withoutLyrics: boolean?)
    local playing = ctx.data.media
    if not playing or playing.title == "" then
        return nil
    end
    local repeatMode = playing.repeatMode
    local m = { title = playing.title, artist = playing.artist, album = playing.album, bundle = playing.bundle,
        app = if playing.app ~= "" then playing.app else playing.bundle, artwork = playing.artwork,
        playing = playing.playing, shuffle = playing.shuffle, repeatMode = repeatMode,
        repeating = repeatMode == "one" or repeatMode == "all",
        playSymbol = if playing.playing then "pause.fill" else "play.fill",
        repeatSymbol = if repeatMode == "one" then "repeat.1" else "repeat",
        toggle = TOGGLE, previous = "media previous", next = "media next", open = "media open",
        shuffleCommand = "media shuffle", repeatCommand = "media repeat" }
    if not compact then
        local duration = playing.duration
        local position = playing.elapsed or 0
        if playing.playing then
            position += math.max(0, ctx.data.seconds - playing.sampledAt) * playing.rate
        end
        m.position = math.max(0, position)
        if duration and duration > 0 then
            m.position = math.min(m.position, duration)
        end
        if duration and duration > 0 and playing.elapsed ~= nil then
            m.duration = duration
            m.fraction = m.position / duration
            m.elapsedText = clock(m.position)
            m.durationText = clock(duration)
            m.seek = function(_, event)
                if event.value and event.phase == "ended" then
                    omniwm.run(seek(event.value * duration))
                end
            end
        end
        if not withoutLyrics then
            m.lyrics = lyrics(ctx, m.position)
        end
    end
    return m
end

local function cover(m, size: number)
    local radius = look.radius(8)
    if m.artwork then
        return ui.image{ image = m.artwork, w = size, h = size, radius = radius }
    end
    return ui.stack{ w = size, h = size, radius = radius, fill = "foreground/0.06",
        ui.icon{ app = m.bundle, w = size * 0.5625, h = size * 0.5625, placeholder = "music.note" } }
end

local function lyricRows(m, width: number, inner: number)
    local lyric = m.lyrics
    if not lyric then
        return nil
    end
    local rows = { w = width, gap = 4, look.heading(omniwm.l10n("Lyrics")) }
    if lyric.visible then
        for _, line in lyric.visible do
            rows[#rows + 1] = ui.row{ w = inner, pad = 4, radius = look.radius(6), hover = look.hover,
                onClick = line.seek,
                look.text{ text = line.text, size = 13, maxWidth = inner - 8, lines = 2,
                    weight = if line.current then "semibold" else nil,
                    color = if line.current then "accent" else "secondaryForeground" } }
        end
    else
        rows[#rows + 1] = look.text{ text = lyric.message, size = 13, color = "secondaryForeground" }
    end
    return look.group(rows)
end

function media.content(ctx, compact: boolean?, width: number?, m)
    width = width or look.width
    m = m or media.model(ctx, compact)
    local inner = width - 24
    if not m then
        return look.group{ w = width,
            look.text{ text = omniwm.l10n("Nothing is playing"), size = 13, color = "secondaryForeground" } }
    end
    local rows = { w = width, gap = 12,
        ui.row{ w = inner, gap = 12,
            cover(m, 64),
            ui.column{ gap = 3, center = false,
                look.text{ text = m.title, size = 14, weight = "semibold", maxWidth = inner - 76, lines = 2 },
                look.text{ text = m.artist, size = 13, color = "secondaryForeground", maxWidth = inner - 76 },
                if not compact then look.text{ text = m.album, size = 11, color = "secondaryForeground",
                    maxWidth = inner - 76 } else nil } } }
    if not compact and m.duration then
        rows[#rows + 1] = ui.column{ gap = 4,
            ui.slider{ value = m.fraction, w = inner, h = 12, onChange = m.seek },
            ui.row{ w = inner,
                look.text{ text = m.elapsedText, size = 11, color = "secondaryForeground" },
                ui.box{ grow = 1 },
                look.text{ text = m.durationText, size = 11, color = "secondaryForeground" } } }
    end
    local controls = { w = inner, gap = 8, ui.box{ grow = 1 } }
    if m.shuffle ~= nil then
        controls[#controls + 1] = look.button("shuffle", m.shuffleCommand, { active = m.shuffle })
    end
    controls[#controls + 1] = look.button("backward.fill", m.previous)
    controls[#controls + 1] = look.button(m.playSymbol, m.toggle, { primary = true })
    controls[#controls + 1] = look.button("forward.fill", m.next)
    if m.repeatMode ~= nil then
        controls[#controls + 1] = look.button(m.repeatSymbol, m.repeatCommand, { active = m.repeating })
    end
    controls[#controls + 1] = ui.box{ grow = 1 }
    controls[#controls + 1] = look.button("arrow.up.forward.app", m.open)
    rows[#rows + 1] = ui.row(controls)
    local content = look.group(rows)
    local lyric = not compact and lyricRows(m, width, inner)
    if not lyric then
        return content
    end
    return ui.column{ w = width, gap = 12, center = false, content, lyric }
end

return table.freeze(media)
