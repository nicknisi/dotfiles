-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local SIZES = { text = 13, small = 11, symbol = 14, icon = 18, slot = 22, time = 13, glyph = 18 }

local function skin(look)
    look.base = look.base or 32
    look.hover = look.hover or "foreground/0.08"
    look.width = look.width or 320
    look.widths = look.widths or {}
    look.panelInset = look.panelInset or 0
    look.verticalText = look.verticalText or "hide"
    look.symbols = look.symbols or {}
    look.notification = look.notification or {}
    local sizes = table.clone(SIZES)
    for role, value in look.size or {} do
        sizes[role] = value
    end
    look.size = sizes

    look.scale = look.scale or function(ctx)
        return ctx.data.bar.style.height / look.base
    end
    look.px = look.px or function(ctx, role)
        return look.size[role] * look.scale(ctx)
    end
    look.radius = look.radius or function(value)
        return value
    end
    look.panelWidth = look.panelWidth or function(name)
        return look.widths[name] or look.width
    end
    look.text = look.text or function(props)
        if props.color == nil and props.role == "secondary" then
            props.color = "secondaryForeground"
        end
        props.role = nil
        return ui.text(props)
    end
    look.glyph = look.glyph or function(props)
        props.name = look.symbols[props.name] or props.name
        return ui.symbol(props)
    end
    look.hue = look.hue or function()
        return nil
    end
    look.batterySymbol = look.batterySymbol or function(level, charging)
        if charging then
            return "battery.100percent.bolt"
        end
        if level > 85 then
            return "battery.100percent"
        end
        if level > 60 then
            return "battery.75percent"
        end
        if level > 35 then
            return "battery.50percent"
        end
        if level > 10 then
            return "battery.25percent"
        end
        return "battery.0percent"
    end
    local function capsuled(ctx)
        local bar = ctx and ctx.data.bar and ctx.data.bar.style
        return look.capsules and bar and bar.transparent and bar.backgrounds
    end
    look.bar = look.bar or function(ctx, props)
        local bar = ctx.data.bar.style
        local scale = look.scale(ctx)
        local capsule = capsuled(ctx)
        local size = bar.height - 4
        props.gap = props.gap or 5 * scale
        props.pad = props.pad or 4 * scale
        props.radius = look.radius(6 * scale)
        if props.onClick or props.onRightClick then
            props.hover = props.hover or look.hover
        end
        if props.symbol then
            table.insert(props, 1, look.glyph{ name = props.symbol, size = look.px(ctx, "symbol"), color = props.tint })
        end
        if capsule then
            props.radius = size / 2
            props.fill = props.fill or "surface"
            props.border = props.border or "border"
            props.borderWidth = props.borderWidth or 0.5
            local edge = math.max(0, math.round(size * 0.3) - props.gap)
            if not bar.vertical and not props.w then
                props.pad = 0
                table.insert(props, 1, ui.box{ w = edge, h = 1 })
                props[#props + 1] = ui.box{ w = edge, h = 1 }
            elseif bar.vertical and not props.h then
                props.pad = 0
                table.insert(props, 1, ui.box{ w = 1, h = edge })
                props[#props + 1] = ui.box{ w = 1, h = edge }
            end
        elseif bar.backgrounds then
            props.fill = props.fill or "foreground/0.06"
        end
        props.symbol = nil
        props.tint = nil
        props.hue = nil
        props.joined = nil
        if capsule and props.w and props.w == props.h then
            props.pad = 0
            return ui.stack(props)
        end
        if bar.vertical then
            props.w = props.w or size
            return ui.column(props)
        end
        props.h = props.h or size
        return ui.row(props)
    end
    look.notificationBadge = look.notificationBadge or function(item, mode, m)
        local dx = math.max(0, m.margin - 4)
        local dy = m.margin - math.max(2, m.icon * 0.12)
        if mode == "dot" then
            local size = math.max(6, m.icon * 0.35)
            return ui.box{ align = "topLeading", dx = dx, dy = dy, w = size, h = size, radius = size / 2, fill = "badge" }
        end
        local fit = math.min(1, m.scale)
        local inset = m.icon < 20 and 1 or 3
        local height = math.max(12 * fit, m.icon * 0.55)
        return ui.row{ align = "topLeading", dx = dx, dy = dy, h = height, radius = height / 2, fill = "badge",
            ui.box{ w = inset, h = 1 },
            look.text{ text = item.badge, style = "mono", size = math.max(10 * fit, m.icon * 0.35), weight = "semibold",
                color = "#FFFFFFFF", maxWidth = m.slot - inset * 2 },
            ui.box{ w = inset, h = 1 } }
    end
    look.panel = look.panel or function(ctx, props)
        props.pad = props.pad or 14
        props.gap = props.gap or 12
        props.radius = look.radius(20)
        props.material = "glass"
        props.center = false
        if capsuled(ctx) then
            props.radius = 14
            props.material = "clear"
            props.fill = "background"
            props.border = "border"
            props.borderWidth = 1
        end
        return ui.column(props)
    end
    look.group = look.group or function(props)
        props.pad = props.pad or 12
        props.gap = props.gap or 8
        props.radius = look.radius(12)
        props.fill = props.fill or "surface"
        props.center = false
        return ui.column(props)
    end
    look.list = look.list or function(props)
        props.divided = nil
        props.gap = props.gap or 2
        return ui.column(props)
    end
    look.heading = look.heading or function(text, width)
        return ui.row{ w = width, look.text{ text = text, size = 14, weight = "semibold" } }
    end
    look.section = look.section or function(text, width)
        return look.heading(text, width)
    end
    look.primaryButton = look.primaryButton or { w = 36, h = 36, radius = look.radius(18), fill = "foreground/0.06" }
    local drawButton = look.button or function(name, action, props)
        local color = props.color
        props.color = nil
        props.w = props.w or 28
        props.h = props.h or 28
        props.radius = props.radius or look.radius(7)
        props.hover = look.hover
        props.onClick = action
        props[#props + 1] = look.glyph{ name = name, size = 14, weight = "medium", color = color }
        return ui.stack(props)
    end
    look.button = function(name, action, props)
        props = props or {}
        if props.primary then
            for key, value in look.primaryButton do
                if props[key] == nil then
                    props[key] = value
                end
            end
        end
        if props.active then
            props.color = props.color or "accent"
        end
        props.primary = nil
        props.active = nil
        return drawButton(name, action, props)
    end
    return table.freeze(look)
end

return skin
