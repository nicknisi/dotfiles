-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")

function render(ctx)
    local settings = ctx.data.settings or {}
    local state = { symbol = settings.symbol or "magnifyingglass",
        command = if settings.mode then "open-command-palette " .. settings.mode else "open-command-palette" }
    local behaviour = { onClick = state.command, help = omniwm.l10n("Toggle Command Palette") }
    local button = look.launcherBar and look.launcherBar(ctx, state)
    if not button then
        local props = table.clone(behaviour)
        props[1] = look.glyph{ name = state.symbol, size = 14 * look.scale(ctx), weight = "medium" }
        button = look.bar(ctx, props)
    end
    for key, value in behaviour do
        button[key] = value
    end
    return button
end
