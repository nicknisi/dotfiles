local effects = require("../lib/effects")
local texture = omniwm.asset("@self/sample.png")

local motions = {
    { "pop", omniwm.l10n("Pop") }, { "slide", omniwm.l10n("Slide") }, { "fade", omniwm.l10n("Fade") },
    { "spring", omniwm.l10n("Spring") }, { "stretch", omniwm.l10n("Stretch") },
    { "indicator", omniwm.l10n("Indicator") },
}
local lights = {
    { "aurora", omniwm.l10n("Aurora") }, { "sheen", omniwm.l10n("Sheen") },
    { "glow", omniwm.l10n("Inner glow") }, { "ring", omniwm.l10n("Gradient ring") },
    { "rotating-border", omniwm.l10n("Rotating border") },
}
local masks = {
    { "circle", omniwm.l10n("Circle") }, { "wipe", omniwm.l10n("Wipe") },
    { "dissolve", omniwm.l10n("Dissolve") },
    { "burn", omniwm.l10n("Burn") }, { "smoke", omniwm.l10n("Smoke") },
}

local function button(label, selected, action, width)
    return ui.column{ w = width, pad = 8, radius = 9, center = true, help = label,
        fill = if selected then "accent/0.18" else "foreground/0.05", hover = "foreground/0.12",
        pressScale = 0.95, pressAnimate = { response = 0.18, bounce = 0 }, onClick = action,
        ui.text{ text = label, size = 12, color = if selected then "accent" else "foreground" } }
end

local function choices(ctx, key, entries, fallback)
    local rows = { gap = 6 }
    local columns = if #entries > 4 then 3 else #entries
    for first = 1, #entries, columns do
        local row = { gap = 6 }
        for index = first, math.min(first + columns - 1, #entries) do
            local entry = entries[index]
            row[#row + 1] = button(entry[2], (ctx.state[key] or fallback) == entry[1], function(next)
                next.state[key] = entry[1]
                next.state.hidden = false
            end, (360 - (columns - 1) * 6) / columns)
        end
        rows[#rows + 1] = ui.row(row)
    end
    return ui.column(rows)
end

local function control(label, value, display, change)
    return ui.column{ gap = 3, center = false,
        ui.row{ w = 360,
            ui.text{ text = label, grow = 1, size = 11, color = "secondaryForeground" },
            ui.text{ text = display, size = 11, style = "mono" } },
        ui.slider{ w = 360, h = 22, value = value, help = label,
            onChange = function(next, event)
                if event.value then change(next, math.clamp(event.value, 0, 1)) end
            end } }
end

local function playback(ctx)
    return button(if ctx.state.replaying then omniwm.l10n("Stop preview") else omniwm.l10n("Play preview"),
        ctx.state.replaying == true, function(next) next.state.replaying = not next.state.replaying end, 360)
end

local function progressControl(ctx)
    local progress = ctx.state.progress or 0.6
    return control(omniwm.l10n("Reveal progress"), progress, string.format("%d%%", math.round(progress * 100)),
        function(next, value) next.state.progress = value; next.state.replaying = false end)
end

local function sample()
    return ui.column{ gap = 6, center = true,
        ui.symbol{ name = "sparkles", w = 28, h = 28, color = "accent" },
        ui.text{ text = omniwm.l10n("Make it yours"), size = 18, weight = "semibold" },
        ui.text{ text = omniwm.l10n("Editable effects, native motion"), size = 11, color = "secondaryForeground" } }
end

local function motionPreview(ctx)
    local name = ctx.state.motion or "pop"
    local stage = { w = 360, h = 158, radius = 16, fill = "foreground/0.04", center = true }
    if name == "indicator" then
        stage[#stage + 1] = ui.box{ w = 280, h = 8, radius = 4, fill = "foreground/0.08" }
        stage[#stage + 1] = ui.box(effects.motion(name, {
            key = "indicator", w = 70, h = 8, radius = 4, fill = "accent",
            dx = if ctx.state.shifted then 95 else -95,
        }))
    elseif not ctx.state.hidden then
        stage[#stage + 1] = ui.stack(effects.motion(name, {
            key = "motion-" .. name, w = 300, h = 122, radius = 16, fill = "surface", center = true,
            shadow = "#00000025", shadowRadius = 8, sample(),
        }))
    end
    local label = if name == "indicator" then omniwm.l10n("Move")
        elseif ctx.state.hidden then omniwm.l10n("Show") else omniwm.l10n("Hide")
    return ui.column{ gap = 10,
        choices(ctx, "motion", motions, "pop"), ui.stack(stage),
        button(label, false, function(next)
            if name == "indicator" then next.state.shifted = not next.state.shifted
            else next.state.hidden = not next.state.hidden end
        end, 360),
        ui.text{ text = omniwm.l10n("Stretch also plays when this panel opens."), size = 11,
            color = "secondaryForeground", maxWidth = 360 } }
end

local function lightPreview(ctx)
    local name = ctx.state.light or "aurora"
    return ui.column{ gap = 10,
        choices(ctx, "light", lights, "aurora"),
        ui.stack{ w = 360, h = 180, radius = 16, material = "regular", fill = "surface/0.45", center = true,
            effects.shader(name, if ctx.state.paused then { fps = 0 } else nil), sample() },
        button(if ctx.state.paused then omniwm.l10n("Animate") else omniwm.l10n("Freeze"),
            ctx.state.paused == true, function(next) next.state.paused = not next.state.paused end, 360),
        ui.text{ text = omniwm.l10n("Aurora and rotating borders animate. Freeze resets time."), size = 11,
            color = "secondaryForeground", maxWidth = 360 } }
end

local function maskPreview(ctx)
    local name = ctx.state.mask or "circle"
    local progress = if ctx.state.replaying then -2 else ctx.state.progress or 0.6
    local values = if name == "circle" then { 0.5, 0.5, 1, progress }
        elseif name == "wipe" then { 1, 0, 1, progress }
        elseif name == "burn" then { 26, 0.015, 0, progress }
        elseif name == "smoke" then { 60, 0.14, 0, progress } else { 8, 1, 0, progress }
    local overlay = if name == "burn" or name == "smoke"
        then effects.shader(name, { values = { values[1], values[2], 1, progress },
            fps = if ctx.state.replaying then 30 else 0 }) else nil
    return ui.column{ gap = 10,
        choices(ctx, "mask", masks, "circle"),
        ui.stack{ w = 360, h = 180, radius = 16, fill = "foreground/0.04", center = true,
            ui.stack{ w = 360, h = 180, radius = 16, material = "regular", fill = "accent/0.1", center = true,
                effects.mask(name, { values = values, fps = if ctx.state.replaying then 30 else 0 }), sample() },
            overlay },
        progressControl(ctx), playback(ctx),
        ui.text{ text = omniwm.l10n("The mask reveals the material, text and icon together."), size = 11,
            color = "secondaryForeground", maxWidth = 360 } }
end

local function blurPreview(ctx)
    local radius = ctx.state.blurRadius or 20
    local saturation = ctx.state.saturation or 1.8
    local tint = ctx.state.tint or 0.12
    return ui.column{ gap = 10,
        ui.stack{ w = 360, h = 180, radius = 16, center = true,
            ui.image{ image = texture, w = 360, h = 180, radius = 16 },
            ui.stack{ w = 300, h = 138, radius = 16, material = "regular", blurRadius = radius,
                saturation = saturation, fill = string.format("surface/%.3f", tint), center = true, sample() } },
        control(omniwm.l10n("Blur radius"), radius / 64, string.format("%.0f pt", radius),
            function(next, value) next.state.blurRadius = value * 64 end),
        control(omniwm.l10n("Saturation"), saturation / 3, string.format("%.2f", saturation),
            function(next, value) next.state.saturation = value * 3 end),
        control(omniwm.l10n("Tint opacity"), tint, string.format("%d%%", math.round(tint * 100)),
            function(next, value) next.state.tint = value end),
        button(omniwm.l10n("Reset blur"), false, function(next)
            next.state.blurRadius = nil; next.state.saturation = nil; next.state.tint = nil
        end, 360),
        ui.text{ text = omniwm.l10n("Native backdrop controls. Liquid Glass keeps its own appearance."),
            size = 11, color = "secondaryForeground", maxWidth = 360 } }
end

local function texturePreview(ctx)
    local name = ctx.state.textureEffect or "pixelate"
    local progress = if ctx.state.replaying then -2 else ctx.state.progress or 0.6
    local block = ctx.state.block or 48
    local anchor = ctx.state.anchor or 0.5
    local values = if name == "pixelate" then { block, 0, 0, progress }
        else { anchor, if ctx.state.top then 1 else 0, 0, progress }
    return ui.column{ gap = 10,
        choices(ctx, "textureEffect", {
            { "pixelate", omniwm.l10n("Pixelation") }, { "genie", omniwm.l10n("Genie") },
        }, "pixelate"),
        ui.stack{ w = 360, h = 180, radius = 16, material = "regular", fill = "foreground/0.04",
            effects.shader(name, { texture = texture, values = values, radius = 16,
                fps = if ctx.state.replaying then 30 else 0 }) },
        progressControl(ctx),
        if name == "pixelate" then control(omniwm.l10n("Pixel block size"), block / 96,
            string.format("%.0f pt", block), function(next, value) next.state.block = value * 96 end)
        else control(omniwm.l10n("Genie anchor"), anchor, string.format("%d%%", math.round(anchor * 100)),
            function(next, value) next.state.anchor = value end),
        playback(ctx),
        ui.text{ text = omniwm.l10n("Sampled image pixels. Edit sample.png or set your own texture."),
            size = 11, color = "secondaryForeground", maxWidth = 360 },
        if name == "genie" then button(if ctx.state.top then omniwm.l10n("Anchor: top") else omniwm.l10n("Anchor: bottom"),
            false, function(next) next.state.top = not next.state.top end, 360) else nil }
end

function render(ctx)
    local vertical = ctx.data.bar and ctx.data.bar.style.vertical
    local props = { gap = 5, pad = 4, radius = 8, hover = "foreground/0.08", popout = true,
        help = omniwm.l10n("Effects Lab"), ui.symbol{ name = "sparkles", w = 15, h = 15 } }
    if not vertical then props[#props + 1] = ui.text{ text = omniwm.l10n("Effects"), size = 12 } end
    return if vertical then ui.column(props) else ui.row(props)
end

function popout(ctx)
    local tab = ctx.state.tab or "motion"
    local glass = ctx.state.glass ~= false
    return ui.column{ w = 392, pad = 16, gap = 12, material = if tab == "blur" then "clear" elseif glass then "glass" else "regular",
        fill = if tab == "blur" then "surface/0.75" else nil,
        open = 0.55, close = 0.25,
        ui.row{ w = 360,
            ui.column{ gap = 3, grow = 1, center = false,
                ui.text{ text = omniwm.l10n("Effects Lab"), size = 20, weight = "semibold" },
                ui.text{ text = omniwm.l10n("Motion · Light · Reveal · Texture"), size = 11, color = "secondaryForeground" } },
            if tab == "blur" then ui.text{ text = omniwm.l10n("Backdrop"), size = 11, color = "secondaryForeground" }
            else button(if glass then omniwm.l10n("Glass") else omniwm.l10n("Frosted"), glass,
                function(next) next.state.glass = not glass end, 76) },
        ui.row{ gap = 6,
            button(omniwm.l10n("Motion"), tab == "motion", function(next) next.state.tab = "motion" end, 67.2),
            button(omniwm.l10n("Light"), tab == "light", function(next) next.state.tab = "light" end, 67.2),
            button(omniwm.l10n("Masks"), tab == "masks", function(next) next.state.tab = "masks" end, 67.2),
            button(omniwm.l10n("Blur"), tab == "blur", function(next) next.state.tab = "blur" end, 67.2),
            button(omniwm.l10n("Texture"), tab == "texture", function(next) next.state.tab = "texture" end, 67.2) },
        if tab == "motion" then motionPreview(ctx) elseif tab == "light" then lightPreview(ctx)
        elseif tab == "masks" then maskPreview(ctx) elseif tab == "blur" then blurPreview(ctx) else texturePreview(ctx),
    }
end
