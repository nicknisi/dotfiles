-- Celestial-style status pill: Wi-Fi, battery and Keep Awake as small icons in one Wayline pill.
-- Each icon opens its own popout. Battery shows its percentage only when low or charging, Keep Awake
-- shows time left on a timed run; right-click the cup to toggle keep-awake.
interval = 30

local look = require("../lib/look")
local wifi = require("../lib/wifi")
local battery = require("../lib/battery")
local awake = require("../lib/awake")

local FLOAT = {}
for i = 0, 200 do
    FLOAT[i + 1] = -math.abs(math.sin(i / 200 * 30 / 3 * math.pi)) * 1.2 -- drift up and settle every 3s
end
FLOAT[#FLOAT] = 0 -- pulses must end exactly at zero

local function entry(ctx, part: string, help: string, children, extra)
    local props = { key = part, gap = 4, popout = true, help = help, radius = 6, hover = "accent/0.15",
        onClick = function(c) c.state.part = part end }
    for _, child in children do props[#props + 1] = child end
    for key, value in extra or {} do props[key] = value end
    return ui.row(props)
end

function render(ctx)
    local style = ctx.data.bar.style
    local scale = style.height / 40
    local size = 32 * scale
    local glyph = 17 * scale
    local items = {}

    local net = wifi.state(ctx)
    if net then
        items[#items + 1] = entry(ctx, "wifi", net.help, {
            if net.power then wifi.fan(net.level, glyph, "accent", "accent/0.3")
                else ui.symbol{ name = "wifi.slash", size = glyph, color = "secondaryForeground" } })
    end

    local power = battery.state(ctx)
    if power then
        local hue = if power.low then "red" elseif power.charging then "green" else "accent"
        local children = { ui.symbol{ name = power.symbol, size = glyph, weight = "semibold", color = hue } }
        if power.low or power.charging then
            children[2] = ui.text{ text = power.text, font = "Monaspace Neon", size = 13 * scale, weight = "semibold", color = hue }
        end
        items[#items + 1] = entry(ctx, "battery", power.percent, children)
    end

    local on, left = awake.on(ctx), awake.remaining(ctx)
    -- While awake the cup steams and gently floats (a 30s pulse re-keyed each render keeps it going).
    local cup = { ui.symbol{ name = if on then "cup.and.heat.waves.fill" else "cup.and.saucer", size = glyph * 0.9,
        weight = "semibold", color = if on then "accent" else "secondaryForeground",
        pulse = if on then { key = math.floor(ctx.data.seconds / 30), duration = 30, dy = FLOAT } else nil } }
    if left then
        cup[2] = ui.text{ text = left, font = "Monaspace Neon", size = 13 * scale, weight = "semibold", color = "accent" }
    end
    items[#items + 1] = entry(ctx, "awake", if on then "Keeping awake (right-click to stop)"
        else "Keep awake (right-click for indefinitely)", cup, { onRightClick = awake.toggle })

    local pill = { gap = 4 * scale, pad = 7 * scale, h = size, radius = math.floor(size * 0.24),
        fill = "elevatedSurface" }
    if look.pill then look.pill(pill, ctx) end -- a bar look can restyle the pill (Phosphor outlines it)
    for _, item in items do pill[#pill + 1] = item end
    return ui.row(pill)
end

function popout(ctx)
    local part = ctx.state.part
    if part == "wifi" then return wifi.popout(ctx) end
    if part == "battery" then return battery.popout(ctx) end
    return awake.popout(ctx)
end
