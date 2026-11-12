-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local presentation = require("../lib/notification-style")
local relativeTime = require("../lib/notification-time")

local WIDTH = 392
local PAGE = 8
local TEXT_PAGE = 8
local function consume() end

local function button(title, action)
    return presentation.button(title, action or consume, action ~= nil)
end

local function visibleItems(value)
    if not value then return {} end
    if not value.dispatched or #value.dispatched == 0 then return value.items or {} end
    local dispatched = {}
    for _, id in value.dispatched or {} do dispatched[string.lower(id)] = true end
    local items = {}
    for _, item in value.items or {} do
        if not dispatched[string.lower(item.id)] then items[#items + 1] = item end
    end
    return items
end

local function canDismiss(value)
    return value and value.membershipComplete
        and (value.state == "ready" or value.state == "empty" or value.state == "incomplete")
end

local function allSourcesSupported(value)
    for _, item in visibleItems(value) do
        if not item.actionsSupported then return false end
    end
    return true
end

local function sourceStatus(value)
    if not allSourcesSupported(value) then
        if not value.metadataComplete then
            return omniwm.l10n("Some notification details could not be read. Some sources cannot be cleared. Clear supported notifications individually.")
        end
        return omniwm.l10n("Some notification sources cannot be cleared. Clear supported notifications individually.")
    end
    return nil
end

local function replyAction(item)
    local reply = nil
    for _, action in item.actions or {} do
        if type(action) == "table" and type(action.title) == "string" and action.title ~= ""
            and type(action.textInputButtonTitle) == "string" and action.textInputButtonTitle ~= "" then
            if reply then return nil end
            reply = action
        end
    end
    if reply then
        local count = 0
        for _, action in item.actions or {} do
            if type(action) == "table" and action.title == reply.title then count += 1 end
        end
        if count ~= 1 then return nil end
    end
    return reply
end

local function actionMessage(action)
    if not action then return nil end
    if action.state == "pending" then
        return if action.kind == "reply" then omniwm.l10n("Submitting reply…") else omniwm.l10n("Dismissing notification…")
    elseif action.state == "dispatched" then
        return if action.kind == "reply" then omniwm.l10n("Reply submitted to Notification Center.") else omniwm.l10n("Dismiss requested in Notification Center.")
    elseif action.state == "dispatchedPanelOpen" then
        return omniwm.l10n("Action submitted. Close Notification Center to continue.")
    elseif action.state == "failedPanelOpen" then
        return omniwm.l10n("The action failed. Close Notification Center and try again.")
    elseif action.state == "notFound" then
        return omniwm.l10n("This notification is no longer available in Notification Center.")
    elseif action.state == "historyClosed" then
        return omniwm.l10n("Notification Center closed.")
    elseif action.state == "denied" then
        return omniwm.l10n("Accessibility access is required for notification actions.")
    elseif action.state == "unavailable" then
        return omniwm.l10n("Notification Center is unavailable.")
    elseif action.state == "ambiguous" then
        return omniwm.l10n("The native notification action could not be matched uniquely.")
    elseif action.state == "unsupported" then
        return omniwm.l10n("This native notification action is unavailable.")
    elseif action.state == "failed" then
        return omniwm.l10n("The native notification action failed.")
    elseif action.state == "cancelled" then
        return omniwm.l10n("Notification action cancelled.")
    elseif action.state == "timeout" then
        return omniwm.l10n("Notification Center did not complete the action.")
    end
    return nil
end

local function emptyReply(value)
    for _, scalar in utf8.codes(value) do
        if not ((scalar >= 9 and scalar <= 13) or scalar == 32 or scalar == 133 or scalar == 160
            or scalar == 5760 or (scalar >= 8192 and scalar <= 8203) or scalar == 8232 or scalar == 8233
            or scalar == 8239 or scalar == 8287 or scalar == 12288) then
            return false
        end
    end
    return true
end

local function syncReplies(ctx, value)
    ctx.state.drafts = ctx.state.drafts or {}
    local action = if value then value.action else nil
    local key = if action then action.bundle .. ":" .. action.id .. ":" .. action.kind .. ":" .. action.state else nil
    if key ~= ctx.state.lastAction then
        ctx.state.lastAction = key
        local matching = false
        for _, item in (if value then value.items or {} else {}) do
            if string.lower(item.id) == (if action then action.id else nil) and item.bundle == action.bundle then
                matching = true
                break
            end
        end
        if action and matching and (action.state == "dispatched" or action.state == "dispatchedPanelOpen") and action.kind == "reply" then
            ctx.state.drafts[action.id] = nil
            if ctx.state.reply == action.id then
                ctx.state.reply = nil
                ctx.state.replyError = nil
            end
        end
    end
    if canDismiss(value) then
        local retained = {}
        for _, item in value.items or {} do retained[string.lower(item.id)] = true end
        for id in ctx.state.drafts do
            if not retained[id] then ctx.state.drafts[id] = nil end
        end
        if ctx.state.reply and not retained[ctx.state.reply] then
            ctx.state.reply = nil
            ctx.state.replyError = nil
        end
    end
end

local function composer(ctx, item, action, width, busy)
    local id = string.lower(item.id)
    local draft = ctx.state.drafts[id] or ""
    local function send(next, event)
        if busy then return end
        local value = if event and event.text then event.text else next.state.drafts[id] or ""
        next.state.drafts[id] = value
        if string.find(value, "\0", 1, true) then
            next.state.replyError = omniwm.l10n("Reply contains unsupported characters.")
            return
        end
        if emptyReply(value) then
            next.state.replyError = omniwm.l10n("Reply cannot be empty.")
            return
        end
        if #value > 4096 then
            next.state.replyError = omniwm.l10n("Reply exceeds the 4096-byte limit.")
            return
        end
        local encoded = table.create(#value)
        for index = 1, #value do encoded[index] = string.format("%02x", string.byte(value, index)) end
        next.state.replyError = nil
        omniwm.run("notifications reply " .. item.bundle .. " " .. id .. " " .. table.concat(encoded))
    end
    local function cancel(next)
        next.state.reply = nil
        next.state.replyError = nil
    end
    local rows = { w = width, pad = 6, gap = 6, center = false, onClick = consume,
        ui.input{ key = "notification-reply-" .. id, w = width - 12, h = 72, multiline = true, maxLength = 1024,
            text = draft, placeholder = if type(action.textInputPlaceholder) == "string" then action.textInputPlaceholder else nil,
            focus = true, color = "foreground",
            onChange = function(next, event)
                if event.text == nil then return end
                next.state.drafts[id] = event.text
                next.state.replyError = nil
            end,
            onCommit = send, onCancel = cancel },
        ui.row{ gap = 6,
            button(omniwm.l10n("Send"), if busy or draft == "" then nil else send),
            button(omniwm.l10n("Cancel"), cancel) } }
    if ctx.state.replyError then
        rows[#rows + 1] = presentation.text{ text = ctx.state.replyError, style = "small", color = "secondaryForeground",
            maxWidth = width - 12, lines = 4 }
    end
    return presentation.group(rows, true)
end

local function text(rows, value, width, style, color, ctx, key)
    if type(value) ~= "string" or value == "" then
        return
    end
    if not utf8.len(value) then
        rows[#rows + 1] = presentation.text{ text = omniwm.l10n("Data (%lld bytes)", #value), style = "small", color = "secondaryForeground" }
        return
    end
    local starts = { 1 }
    local first = 1
    while first <= #value do
        local following = utf8.offset(value, 1025, first) or (#value + 1)
        local scan = first
        for line = 1, 128 do
            local newline = string.find(value, "\n", scan, true)
            if not newline or newline >= following then
                break
            end
            scan = newline + 1
            if line == 128 then
                following = scan
            end
        end
        starts[#starts + 1] = following
        first = following
    end
    local pages = math.max(1, math.ceil((#starts - 1) / TEXT_PAGE))
    local page = math.clamp(if ctx then (ctx.state.textPages or {})[key] or 1 else 1, 1, pages)
    for index = (page - 1) * TEXT_PAGE + 1, math.min(page * TEXT_PAGE, #starts - 1) do
        rows[#rows + 1] = presentation.text{ text = string.sub(value, starts[index], starts[index + 1] - 1),
            maxWidth = width, lines = 255, style = style, color = color }
    end
    if pages > 1 and ctx then
        local function select(state, selected)
            state.state.textPages = state.state.textPages or {}
            state.state.textPages[key] = selected
        end
        rows[#rows + 1] = ui.row{ gap = 5,
            button(omniwm.l10n("Previous Text"), function(state) select(state, math.max(1, page - 1)) end),
            presentation.text{ text = tostring(page) .. " / " .. tostring(pages), style = "small", color = "secondaryForeground" },
            button(omniwm.l10n("Next Text"), function(state) select(state, math.min(pages, page + 1)) end) }
    end
end

local function label(value)
    if type(value) == "string" then return value end
    if type(value) == "table" then
        for _, shown in { value.displayName, value.name, value.handle } do
            if type(shown) == "string" and shown ~= "" then return shown end
        end
    end
    return nil
end

local function notification(ctx, item)
    local width = WIDTH - 24
    local content = width - 16
    local id = string.lower(item.id)
    local value = ctx.data.notifications
    local action = value.action
    local busy = (action and action.state == "pending") or (value.dismissAll and value.dismissAll.active)
    local rows = { key = item.id, w = width, gap = 5, pad = 8, center = false,
        onClick = if item.actionsSupported then "notifications open " .. item.bundle else nil }
    local app = nil
    for _, candidate in value.apps or {} do
        if candidate.bundle == item.bundle then
            app = candidate
            break
        end
    end
    local name = if app then app.name or item.bundle else item.bundle
    rows[#rows + 1] = ui.row{ w = content, gap = 6,
        ui.icon{ app = item.bundle, w = 18, h = 18, placeholder = "app" },
        presentation.text{ text = name, style = "small", grow = 1, maxWidth = content - 150 },
        presentation.text{ text = relativeTime(ctx, item.date), style = "small", color = "secondaryForeground" },
        button("×", if canDismiss(value) and item.actionsSupported and not busy
            then "notifications dismiss " .. item.bundle .. " " .. id else nil) }
    local seen = {}
    for _, shown in { item.title, item.subtitle } do
        if type(shown) == "string" then seen[shown] = true end
    end
    local communication = item.communication
    if type(communication) == "table" then
        for index, shown in { label(communication.sender), label(communication.conversation) or communication.displayName } do
            if type(shown) == "string" and shown ~= "" and not seen[shown] then
                seen[shown] = true
                text(rows, shown, content, "small", "secondaryForeground", ctx, item.id .. ":communication:" .. index)
            end
        end
    end
    text(rows, item.title, content, "bold", nil, ctx, item.id .. ":title")
    text(rows, item.subtitle, content, "body", "secondaryForeground", ctx, item.id .. ":subtitle")
    local body = item.body
    if type(body) == "string" and body ~= "" then
        local expanded = (ctx.state.expanded or {})[id] == true
        local length = utf8.len(body) or #body
        local newlines = select(2, string.gsub(body, "\n", "\n"))
        local collapsible = length > 180 or newlines >= 3
        if expanded or not collapsible then
            text(rows, body, content, "body", nil, ctx, item.id .. ":body")
        elseif utf8.len(body) then
            local last = utf8.offset(body, 181) or (#body + 1)
            rows[#rows + 1] = presentation.text{ text = string.sub(body, 1, last - 1), maxWidth = content, lines = 3 }
        else
            text(rows, body, content, "body", nil)
        end
        if collapsible then
            rows[#rows + 1] = button(if expanded then omniwm.l10n("Show Less") else omniwm.l10n("Show More"), function(next)
                next.state.expanded = next.state.expanded or {}
                next.state.expanded[id] = not expanded
            end)
        end
    end
    local attachmentIndicator = false
    for _, attachment in item.attachments or {} do
        local image = attachment.image
        if type(image) == "userdata" and image.kind == "image" and image.state == "ready" then
            rows[#rows + 1] = ui.image{ image = image, w = content, h = 144, radius = 6 }
        elseif attachment.available == true then
            attachmentIndicator = true
        end
    end
    if attachmentIndicator then
        text(rows, omniwm.l10n("Attachment"), content, "small", "secondaryForeground")
    end
    local reply = if value.complete == true and item.actionsSupported then replyAction(item) else nil
    if reply then
        rows[#rows + 1] = button(omniwm.l10n("Reply"), if busy then nil else function(next)
            next.state.reply = if next.state.reply == id then nil else id
            next.state.replyError = nil
        end)
        if ctx.state.reply == id then
            rows[#rows + 1] = composer(ctx, item, reply, content, busy)
        end
    end
    if action and action.id == id and action.bundle == item.bundle then
        text(rows, actionMessage(action), content, "small", "secondaryForeground")
    end
    return presentation.group(rows)
end

local function batchMessage(batch)
    if not batch then return nil end
    if batch.state == "pending" then
        return omniwm.l10n("Clearing notifications: %lld of %lld", batch.completed, batch.total)
    elseif batch.state == "cancelling" then
        return omniwm.l10n("Stopping after the current notification…")
    elseif batch.state == "cancelled" then
        return omniwm.l10n("Clear All cancelled. Processed %lld of %lld; %lld failed.", batch.completed, batch.total, batch.failed)
    elseif batch.state == "partial" then
        return omniwm.l10n("Clear All finished. Failed: %lld", batch.failed)
    elseif batch.state == "completed" then
        return omniwm.l10n("Dismissal requested: %lld", batch.completed)
    elseif batch.state == "failed" then
        return omniwm.l10n("Clear All could not finish.")
    end
    return nil
end

local function status(value)
    if not value then
        return omniwm.l10n("Loading notifications…")
    end
    if value.state == "accessDenied" then
        return omniwm.l10n("Notification database access is denied. Check Full Disk Access in System Settings.")
    elseif value.state == "unavailable" then
        return omniwm.l10n("The notification database is unavailable.")
    elseif value.state == "queryError" then
        return omniwm.l10n("The notification database could not be read.")
    elseif value.state == "malformed" then
        return omniwm.l10n("The notification database contains unsupported or malformed data.")
    elseif value.state == "incomplete" or value.complete == false or not value.membershipComplete then
        if value.membershipComplete then
            return sourceStatus(value) or omniwm.l10n("Some notification details could not be read. Notifications can still be cleared.")
        end
        return omniwm.l10n("Some notification data could not be read. The list is incomplete.")
    elseif value.state ~= "ready" and value.state ~= "empty" then
        return omniwm.l10n("Loading notifications…")
    end
    return sourceStatus(value)
end

function render(ctx)
    local value = ctx.data.notifications
    local count = #visibleItems(value)
    local issue = status(value)
    local scale = presentation.scale(ctx)
    local rows = { gap = 4 * scale, onClick = ui.popout,
        help = issue or omniwm.l10n("Notifications"),
        presentation.icon(issue, 14 * scale) }
    if count > 0 then
        local size = if ctx.data.bar.style.vertical then math.min(12 * scale, (ctx.data.bar.style.height - 8) / 2)
            else 12 * scale
        rows[#rows + 1] = presentation.text{ text = tostring(count), style = "small", size = size }
    end
    return presentation.bar(ctx, rows)
end

function popout(ctx)
    local value = ctx.data.notifications
    syncReplies(ctx, value)
    local items = visibleItems(value)
    local busy = value and ((value.action and value.action.state == "pending") or (value.dismissAll and value.dismissAll.active))
    local pages = math.max(1, math.ceil(#items / PAGE))
    local page = math.clamp(ctx.state.page or 1, 1, pages)
    local rows = { w = WIDTH, h = 520, pad = 12, gap = 10, center = false, scroll = true,
        ui.row{ w = WIDTH - 24, gap = 5,
            presentation.text{ text = omniwm.l10n("Notifications"), style = "bold", grow = 1 },
            button(omniwm.l10n("Clear All"),
                if canDismiss(value) and allSourcesSupported(value) and #items > 0 and not busy
                    then "notifications dismiss-all" else nil),
            button(omniwm.l10n("Settings"), "notifications settings") } }
    local issue = status(value)
    if issue then
        text(rows, issue, WIDTH - 24, "body", "secondaryForeground")
    end
    if #items == 0 and canDismiss(value) then
        rows[#rows + 1] = presentation.text{ text = omniwm.l10n("No retained notifications"), color = "secondaryForeground" }
    end
    if value and value.action and value.action.state == "pending" then
        text(rows, omniwm.l10n("Another notification action is still in progress."), WIDTH - 24, "small", "secondaryForeground")
    end
    if value and value.error and value.error ~= "" and value.error ~= "Notification snapshot incomplete" then
        text(rows, value.error, WIDTH - 24, "small", "secondaryForeground")
    end
    if value and value.kept and value.kept > 0 then
        text(rows, omniwm.l10n("macOS kept notifications: %lld", value.kept), WIDTH - 24, "small", "secondaryForeground")
    end
    local panelAction = nil
    local action = if value then value.action else nil
    if action and (action.kind == "dismiss" or action.kind == "reply") and action.state == "dispatchedPanelOpen" then
        for _, id in value.dispatched or {} do
            if string.lower(id) == string.lower(action.id) then
                panelAction = actionMessage(action)
                text(rows, panelAction, WIDTH - 24, "small", "secondaryForeground")
                break
            end
        end
    end
    if value and value.dismissAll then
        local batch = value.dismissAll
        local progress = { w = WIDTH - 24, gap = 6 }
        text(progress, batchMessage(batch), WIDTH - 110, "small", "secondaryForeground")
        if batch.active then
            progress[#progress + 1] = button(omniwm.l10n("Cancel"),
                if batch.state ~= "cancelling" then "notifications cancel-dismiss-all" else nil)
        end
        rows[#rows + 1] = ui.row(progress)
        if batch.outcome and batch.outcome ~= "dispatched" and batch.outcome ~= "cancelled" then
            local message = actionMessage({ state = batch.outcome, kind = "dismiss" })
            if message ~= panelAction then
                text(rows, message, WIDTH - 24, "small", "secondaryForeground")
            end
        end
    end
    for index = (page - 1) * PAGE + 1, math.min(page * PAGE, #items) do
        rows[#rows + 1] = notification(ctx, items[index])
    end
    if pages > 1 then
        rows[#rows + 1] = ui.row{ w = WIDTH - 24, gap = 8, center = true,
            button(omniwm.l10n("Previous"), function(state) state.state.page = math.max(1, page - 1) end),
            presentation.text{ text = tostring(page) .. " / " .. tostring(pages), style = "small", color = "secondaryForeground" },
            button(omniwm.l10n("Next"), function(state) state.state.page = math.min(pages, page + 1) end) }
    end
    return presentation.panel(ctx, rows)
end
