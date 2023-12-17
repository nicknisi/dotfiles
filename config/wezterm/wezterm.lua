-- configure wezterm to use the ~/.config/dotfiles directory for shared lua modules
local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
package.path = package.path .. ";" .. dotfiles .. "/?.lua;" .. dotfiles .. "/?/?.lua;" .. dotfiles .. "/?/init.lua"

local wezterm = require("wezterm")
local util = require("base.util")
local assets = wezterm.config_dir .. "/assets"
local custom_config = require("base.config")

local config = {}

-- base config
config.macos_window_background_blur = 30
config.enable_tab_bar = false
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.native_macos_fullscreen_mode = true
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- font config
config.font = wezterm.font(custom_config.font, { weight = "Regular" })
config.font_rules = {
  {
    italic = true,
    font = wezterm.font(custom_config.italic_font, { weight = "Medium" }),
  },
}
config.harfbuzz_features = { "calt", "dlig", "clig=1", "ss01", "ss02", "ss03", "ss04", "ss05", "ss06", "ss07", "ss08" }
config.font_size = 16
config.line_height = 1.0
config.adjust_window_size_when_changing_font_size = false

-- keys config
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = false

local is_dark = wezterm.gui.get_appearance():find("Dark")

util.table_extend(true, config, require(custom_config.theme)(is_dark, assets))

config = util.table_extend(true, config, custom_config.wezterm_overrides or {})

return config
