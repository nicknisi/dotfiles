-- Keep the Mac awake, Amphetamine-style: click for timed sessions, right-click to toggle.
-- Uses OmniWM's own Prevent Sleep (`session awake on|off|<minutes>`, at most 1440 minutes).
interval = 30

local look = require("../lib/look")
local chip = require("../lib/chip")

local PANEL = 300
local INNER = PANEL - 24 -- wayline's titled panel pads its body by 12
local DURATIONS = { { "15m", 15 }, { "30m", 30 }, { "1h", 60 }, { "2h", 120 }, { "4h", 240 }, { "8h", 480 } }

local function remaining(ctx): string?
    local awake = ctx.data.awake
    local ends = awake and awake["until"]
    if not ends then return nil end
    local mins = math.max(1, math.floor((ends - ctx.data.seconds) / 60))
    return if mins >= 60 then string.format("%dh %02dm", mins // 60, mins % 60) else mins .. "m"
end

local function toggle(ctx)
    omniwm.run(if ctx.data.awake and ctx.data.awake.on then "session awake off" else "session awake on")
end

local function bar(ctx, on: boolean, label: string?)
    local size = 32 * ctx.data.bar.style.height / 40
    return chip(ctx, ui.symbol{ name = if on then "cup.and.saucer.fill" else "cup.and.saucer",
        size = math.floor(size * 0.5), weight = "semibold",
        color = if on then "accentForeground" else "secondaryForeground" },
        if on then "accent" else "elevatedSurface", label, "accent")
end

function render(ctx)
    local on = ctx.data.awake and ctx.data.awake.on or false
    local button = bar(ctx, on, remaining(ctx))
    button.onClick, button.onRightClick = ui.popout, toggle
    button.help = if on then "Keeping awake (right-click to stop)" else "Keep awake (right-click for indefinitely)"
    return button
end

local function option(label: string, command: string, width: number)
    return ui.stack{ w = width, h = 30, radius = 8, fill = "surface", hover = look.hover, onClick = command,
        look.text{ text = label, size = 13, weight = "medium" } }
end

function popout(ctx)
    local on = ctx.data.awake and ctx.data.awake.on
    local left = remaining(ctx)
    local status = if left then "Awake for " .. left .. " more" elseif on then "Awake until turned off" else "Sleep allowed"
    local width = (INNER - 24 - 2 * 8) / 3
    local grid = { w = INNER, gap = 8, fill = "elevatedSurface" }
    for row = 0, 1 do
        local line = { gap = 8 }
        for col = 1, 3 do
            local d = DURATIONS[row * 3 + col]
            line[#line + 1] = option(d[1], "session awake " .. d[2], width)
        end
        grid[#grid + 1] = ui.row(line)
    end
    grid[#grid + 1] = ui.row{ gap = 8,
        option("Indefinitely", "session awake on", (INNER - 24 - 8) / 2),
        option("Off", "session awake off", (INNER - 24 - 8) / 2) }
    return look.panel(ctx, { w = PANEL,
        ui.row{ w = INNER, gap = 8,
            ui.symbol{ name = if on then "cup.and.saucer.fill" else "cup.and.saucer", size = 14, weight = "semibold",
                color = "accent" },
            ui.text{ text = "Keep Awake", size = 14, weight = "bold", grow = 1 },
            look.text{ text = status, size = 12, color = "secondaryForeground" } },
        look.group(grid) })
end
