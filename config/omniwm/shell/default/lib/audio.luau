-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")

local audio = {}
local PRECISE_POINTS_PER_STEP = 12
local TRANSPORT = {
    builtin = "laptopcomputer", usb = "cable.connector", bluetooth = "headphones", hdmi = "display",
    displayport = "display", airplay = "airplayaudio", thunderbolt = "bolt.horizontal",
}

function audio.symbol(volume: number?, muted: boolean?): string
    if not volume then
        return "speaker.fill"
    end
    if muted or volume == 0 then
        return "speaker.slash.fill"
    end
    return if volume < 34 then "speaker.wave.1.fill" elseif volume < 67 then "speaker.wave.2.fill"
        else "speaker.wave.3.fill"
end

function audio.scroll(ctx, event, step: number?)
    local delta = if event.precise then event.dy / PRECISE_POINTS_PER_STEP else event.dy
    local total = ctx.state.scroll or 0
    if total * delta < 0 then
        total = 0
    end
    total += delta
    local steps = if total >= 0 then math.floor(total) else math.ceil(total)
    ctx.state.scroll = total - steps
    if steps ~= 0 then
        local size = step or tonumber((ctx.data.settings or {}).step) or 6.25
        omniwm.run(string.format("volume %s %g", if steps > 0 then "up" else "down", math.abs(steps) * size))
    end
end

local function setVolume(_, event)
    if event.value then
        omniwm.run(string.format("volume set %d", math.round(event.value * 100)))
    end
end

function audio.state(ctx)
    local volume = ctx.data.volume
    local muted = ctx.data.muted == true
    return { volume = volume, muted = muted, level = volume and volume / 100, symbol = audio.symbol(volume, muted),
        percent = volume and ctx.format.percent(volume / 100), set = setVolume, mute = "volume mute",
        muteSymbol = if muted then "speaker.wave.2" else "speaker.slash" }
end

function audio.model(ctx)
    local m = audio.state(ctx)
    m.outputs = {}
    for _, device in ctx.data.outputs or {} do
        local output = { name = device.name, default = device.default == true, transport = device.transport,
            symbol = TRANSPORT[device.transport] or "hifispeaker.fill", select = "volume output " .. device.id }
        m.outputs[#m.outputs + 1] = output
        if output.default then
            m.output = output
        end
    end
    local apps = ctx.data.audioApps
    m.permission = if apps and apps.access == "denied" then "volume permission" else nil
    m.apps = {}
    for _, entry in if apps then apps.apps else {} do
        if entry.playing or entry.muted or entry.volume < 100 then
            local id = entry.id
            m.apps[#m.apps + 1] = { id = id, name = entry.name, playing = entry.playing, muted = entry.muted,
                level = entry.volume / 100, percent = ctx.format.percent(math.round(entry.volume) / 100),
                symbol = if entry.muted then "speaker.slash.fill" else "speaker.wave.2.fill",
                mute = "volume app " .. id .. " mute",
                set = function(_, event)
                    if event.value then
                        omniwm.run(string.format("volume app %s set %d", id, math.round(event.value * 100)))
                    end
                end }
        end
    end
    return m
end

function audio.level(ctx, width: number?, m)
    width = width or look.width
    m = m or audio.state(ctx)
    local inner = width - 24
    if not m.volume then
        return look.group{ w = width,
            look.text{ text = omniwm.l10n("Unavailable"), size = 13, color = "secondaryForeground" } }
    end
    return look.group{ w = width,
        look.heading(omniwm.l10n("Sound")),
        ui.row{ w = inner, gap = 8,
            look.glyph{ name = m.symbol, w = 18, h = 18 },
            ui.slider{ value = m.level, w = inner - 112, h = 16, color = if m.muted then "mutedForeground" else "accent",
                onChange = m.set },
            look.text{ text = m.percent, size = 12, w = 42, reserve = ctx.format.percent(1) },
            look.button(m.muteSymbol, m.mute) } }
end

function audio.content(ctx, width: number?, m)
    width = width or look.width
    m = m or audio.model(ctx)
    local inner = width - 24
    local rows = { w = width, gap = 12, center = false, audio.level(ctx, width, m) }
    local outputs = { w = width, gap = 4, look.heading(omniwm.l10n("Output")) }
    for _, output in m.outputs do
        outputs[#outputs + 1] = ui.row{ w = inner, gap = 8, pad = 6, radius = look.radius(7), hover = look.hover,
            onClick = output.select,
            look.glyph{ name = output.symbol, w = 18, h = 18 },
            look.text{ text = output.name, size = 13, grow = 1, maxWidth = inner - 62,
                weight = if output.default then "semibold" else nil },
            look.glyph{ name = "checkmark", w = 14, h = 14, color = "accent", opacity = if output.default then 1 else 0 } }
    end
    if #outputs > 1 then
        rows[#rows + 1] = look.group(outputs)
    end
    if m.permission then
        rows[#rows + 1] = look.group{ w = width, hover = look.hover, onClick = m.permission,
            ui.row{ w = inner, gap = 8,
                look.glyph{ name = "lock.fill", w = 16, h = 16, color = "secondaryForeground" },
                look.text{ text = omniwm.l10n("Allow System Audio Recording to set app volumes"), size = 13,
                    maxWidth = inner - 24, lines = 2 } } }
    end
    local mixer = { w = width, look.heading(omniwm.l10n("Applications")) }
    for _, app in m.apps do
        mixer[#mixer + 1] = ui.row{ w = inner, gap = 8,
            ui.icon{ app = app.id, w = 18, h = 18, opacity = if app.playing then 1 else 0.6 },
            look.text{ text = app.name, size = 13, w = 92, maxWidth = 92 },
            ui.slider{ value = app.level, w = inner - 162, h = 14, color = if app.muted then "mutedForeground" else "accent",
                onChange = app.set },
            look.button(app.symbol, app.mute) }
    end
    if #mixer > 1 then
        rows[#rows + 1] = look.group(mixer)
    end
    return ui.column(rows)
end

return table.freeze(audio)
