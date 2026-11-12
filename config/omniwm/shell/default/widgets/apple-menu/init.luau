-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local button = require("../lib/menu-button")

function render(ctx: Context)
    if not ctx.data.bar.style.hidesMenuBar then
        return ui.box{ w = 0, h = 0 }
    end
    return button.render(ctx, { symbol = "applelogo", action = "menu apple", help = omniwm.l10n("Apple Menu") })
end
