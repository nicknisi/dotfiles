-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local button = {}

function button.render(ctx: Context, props)
    local style = ctx.data.bar.style
    local size = math.max(16, style.height - 4)
    local icon = math.min(24, math.max(14, size - 8))
    local capsule = style.transparent and style.backgrounds
    local foreground = style.solidBlack and "#FFFFFF" or "foreground"
    local image = if props.symbol then ui.symbol{ name = props.symbol, size = icon, w = icon, h = icon, color = foreground }
        else ui.icon{ app = props.app, pid = props.pid, w = icon, h = icon, placeholder = "app.dashed" }
    return ui.stack{ w = size, h = size, onClick = props.action, help = props.help,
        radius = if capsule then size / 2 else 4, hover = if style.solidBlack then "#FFFFFF1F" else "foreground/0.12",
        image }
end

return button
