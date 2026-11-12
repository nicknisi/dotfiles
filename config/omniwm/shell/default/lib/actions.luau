-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")

local actions = {}

function actions.row(symbol: string, text: string, command: string, width: number, wrap: boolean?)
    return ui.row{ w = width, gap = 8, pad = 6, radius = look.radius(8), hover = look.hover, onClick = command,
        look.glyph{ name = symbol, w = 16, h = 16, color = "secondaryForeground" },
        look.text{ text = text, size = 13, maxWidth = if wrap then width - 40 else nil, lines = if wrap then 2 else nil } }
end

function actions.notice(text: string, width: number)
    return look.group{ w = width, look.text{ text = text, size = 13, color = "secondaryForeground", maxWidth = width - 24 } }
end

return table.freeze(actions)
