-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local style = require("./style")
local presentation = require("./notification-presentation")

return presentation({
    scale = style.scale,
    bar = style.bar,
    hover = style.hover,
    buttonRadius = 2,
    text = function(props)
        props.size = props.size or (if props.style == "small" then 11 else 13)
        props.weight = props.weight or (if props.style == "bold" then "semibold" else nil)
        props.style = "caption"
        return ui.text(props)
    end,
    group = style.group,
    panel = function(_, props) return style.panel(props) end,
})
