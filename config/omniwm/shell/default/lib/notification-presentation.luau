-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local function presentation(look)
    look.text = look.text or ui.text
    look.scale = look.scale or function(ctx) return ctx.data.bar.style.height / 24 end
    look.icon = look.icon or function(issue, size)
        return ui.symbol{ name = if issue then "bell.badge" else "bell", size = size }
    end
    look.bar = look.bar or function(ctx, props)
        props.pad = 2
        props.radius = 4
        props.hover = "foreground/0.12"
        return if ctx.data.bar.style.vertical then ui.column(props) else ui.row(props)
    end
    look.button = look.button or function(title, action, enabled)
        return ui.box{ pad = 5, radius = look.buttonRadius or 5,
            hover = if enabled ~= false then look.hover or "foreground/0.12" else nil,
            opacity = if enabled == false then 0.4 else 1, fill = look.buttonFill, onClick = action,
            look.text{ text = title, style = "small", color = look.buttonForeground } }
    end
    look.group = look.group or function(props, details)
        props.radius = if details then 6 else 8
        props.fill = if details then "foreground/0.04" else "foreground/0.05"
        return ui.column(props)
    end
    look.panel = look.panel or function(_, props) return ui.column(props) end
    return table.freeze(look)
end

return presentation
