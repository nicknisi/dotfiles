-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

return function(ctx, date)
    if type(date) ~= "number" then return "" end
    local age = math.max(0, (ctx.data.seconds or date) - date)
    if age < 60 then return omniwm.l10n("Now") end
    if age < 3600 then return omniwm.l10n("%lld min ago", math.floor(age / 60)) end
    if age < 86400 then return omniwm.l10n("%lld hr ago", math.floor(age / 3600)) end
    if age < 172800 then return omniwm.l10n("Yesterday") end
    return omniwm.l10n("%lld days ago", math.floor(age / 86400))
end
