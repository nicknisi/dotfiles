-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- AeroSpace-style setup, ported from the macOS config.

-- Free the keys Omarchy's defaults sit on that this setup needs.
--   W/S/C/X  letter workspaces (were: close, scratchpad, universal copy/cut)
--   J/K/L    focus keys (were: togglesplit, keybindings menu, layout toggle)
--   SHIFT+{W,A,S,D,X,C} move-to-workspace (were: preinstalled app launchers)
-- SUPER+W became "workspace W", so close window moves to SUPER+Q.
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

local freed = {
	"SUPER + W",
	"SUPER + S",
	"SUPER + C",
	"SUPER + X",
	"SUPER + J",
	"SUPER + K",
	"SUPER + L",
	"SUPER + SHIFT + W",
	"SUPER + SHIFT + A",
	"SUPER + SHIFT + S",
	"SUPER + SHIFT + C",
	"SUPER + SHIFT + X",
	"SUPER + SHIFT + D",
}
for _, keys in ipairs(freed) do
	hl.unbind(keys)
end

-- Letter workspaces (1-9 are already covered by Omarchy's number bindings).
local workspaces = {
	{ key = "W", label = "Web" },
	{ key = "A", label = "AI" },
	{ key = "S", label = "Productivity" },
	{ key = "D", label = "Development" },
	{ key = "Z", label = "Screen share" },
	{ key = "X", label = "Tasks" },
	{ key = "C", label = "Chat" },
}
for _, ws in ipairs(workspaces) do
	-- "name:" prefix is required by the lua layer for named workspaces.
	local name = "name:" .. ws.key
	o.bind("SUPER + " .. ws.key, "Switch to workspace " .. ws.key, hl.dsp.focus({ workspace = name }))
	o.bind("SUPER + SHIFT + " .. ws.key, "Move window to workspace " .. ws.key, hl.dsp.window.move({ workspace = name }))
end

-- Focus with vim keys (arrow keys keep working alongside).
o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Swap windows with vim keys, mirroring SUPER + SHIFT + arrows.
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
