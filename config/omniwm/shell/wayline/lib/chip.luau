-- Wayline's bar chip (as lib/look.luau draws battery and clock): a 32pt square block holding the
-- glyph, optionally attached to a mono label in the same hue. Used by the agents and awake widgets.
return function(ctx, glyph, fill: string, label: string?, labelColor: string?)
    local style = ctx.data.bar.style
    local size = 32 * style.height / 40
    local radius = math.floor(size * 0.24)
    if not label or style.vertical then
        return ui.stack{ w = size, h = size, radius = radius, fill = fill, hoverOpacity = 0.9, glyph }
    end
    return ui.row{ gap = 0, h = size, radius = radius, fill = "elevatedSurface", hoverOpacity = 0.9,
        ui.stack{ w = size, h = size,
            ui.box{ w = size, h = size, radius = radius, fill = fill },
            ui.box{ align = "trailing", w = radius, h = size, fill = fill },
            glyph },
        ui.box{ w = 8, h = 1 },
        ui.text{ text = label, style = "mono", size = 14 * style.height / 40, weight = "semibold",
            color = labelColor or fill },
        ui.box{ w = 9, h = 1 } }
end
