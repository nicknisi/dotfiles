-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local style = require("./style")
local presentation = require("./notification-presentation")

return presentation({
    scale = style.scale,
    bar = style.bar,
    hover = style.hover,
    buttonRadius = 10,
    group = style.group,
    panel = function(_, props) return style.panel(props) end,
})
