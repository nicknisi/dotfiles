-- The live part of Prairie Sky: the real sun or moon over the configured city ([weather] in shell.toml),
-- the temperature, and three little wind turbines spinning at today's actual wind speed.
-- Click for the weather popout.
interval = 300

local look = require("../lib/look")
local weather = require("../lib/weather")

local MONO = "Monaspace Neon"
-- Three blades around a hub (viewBox 12x12), and the turbine's mast.
local BLADES = "M6 6 L5.4 0.6 L6.6 0.6 Z M6 6 L11.1 8.9 L10.5 9.9 Z M6 6 L0.9 8.9 L1.5 9.9 Z M6 4.9 A1.1 1.1 0 1 1 5.99 4.9 Z"

local INK = look.ink -- a look that prints everything in one ink (Bridge's black on console segments)

local function turbine(size: number, period: number, paused: boolean)
    return ui.stack{ w = size, h = size * 1.6,
        ui.box{ align = "bottom", w = math.max(1, size * 0.1), h = size * 0.95, fill = INK or "foreground/0.7" },
        ui.path{ align = "top", w = size, h = size, viewBox = { 0, 0, 12, 12 }, d = BLADES, fill = INK or "foreground",
            loop = { rotate = { 0, 360, period }, paused = paused } } }
end

function render(ctx)
    local state = weather.state(ctx)
    if not state then return ui.box{ w = 0, h = 0 } end
    local s = ctx.data.bar.style.height / 40
    local wind = ctx.select("weather", "wind") or 0
    -- one revolution every 12s in a breeze, down to ~0.6s in a gale; still air stops them
    local period = math.clamp(36 / math.max(wind, 1), 0.6, 12)
    local row = { onClick = ui.popout, gap = 5 * s, pad = 9 * s, h = 28 * s, radius = 14 * s,
        help = (state.condition or "") .. (if wind > 0 then string.format(" · wind %.0f", wind) else ""),
        ui.symbol{ name = state.symbol, size = 14 * s, color = INK or (if state.isDay then "yellow" else "foreground") },
        ui.text{ text = state.temp, font = MONO, size = 13 * s, weight = "semibold", color = INK or "foreground" },
        ui.box{ w = 2 * s, h = 1 },
        turbine(9 * s, period, wind < 1), turbine(7 * s, period * 1.3, wind < 1), turbine(8 * s, period * 0.85, wind < 1) }
    if look.pill then look.pill(row, ctx) else row.fill, row.radius, row.h = "elevatedSurface", math.floor(32 * s * 0.24), 32 * s end
    return ui.row(row)
end

function popout(ctx)
    return weather.popout(ctx)
end
