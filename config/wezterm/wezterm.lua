-- https://wezterm.org/config/files.html
-- Tips:The recommendation is to place your configuration file at $HOME/.wezterm.lua (%USERPROFILE%/.wezterm.lua on Windows) to get started.

-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- color scheme
config.color_scheme = "GitHub Dark"

-- font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 14.0

-- window padding
config.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }

config.initial_cols = 120
config.initial_rows = 28

config.window_decorations = "RESIZE"

-- tab bar
config.tab_max_width = 20

-- launch_menu
config.launch_menu = {
	{ label = "PowerShell", args = { "powershell.exe" } },
	{ label = "Cmd", args = { "cmd.exe" } },
	{ label = "WSL (Ubuntu-22.04)", args = { "wsl.exe", "~", "-d", "Ubuntu-22.04" } },
}

config.default_prog = { "powershell.exe" }

-- local mux = wezterm.mux
-- wezterm.on("gui-startup", function(cmd)
--   local tab, pane, window = mux.spawn_window(cmd or {})
--   window:gui_window():maximize()
-- end)

return config
