local wezterm = require("wezterm")
local utils = require("utils")
local assets = wezterm.config_dir .. "/assets"

local config = {
  -- window_background_opacity = 0.15,
  macos_window_background_blur = 30,
  enable_tab_bar = false,
  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",
  font = wezterm.font("Monaspace Argon", { weight = "Regular" }),
  font_rules = {
    {
      italic = true,
      font = wezterm.font("Monaspace Radon", { weight = "Medium" }),
    },
  },
  harfbuzz_features = { "calt", "dlig", "clig=1", "ss01", "ss02", "ss03", "ss04", "ss05", "ss06", "ss07", "ss08" },
  font_size = 16,
  line_height = 1.0,
  adjust_window_size_when_changing_font_size = true,
  native_macos_fullscreen_mode = true,
  keys = {
    {
      key = "n",
      mods = "SHIFT|CTRL",
      action = wezterm.action.ToggleFullScreen,
    },
  },
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },
  send_composed_key_when_left_alt_is_pressed = true,
  send_composed_key_when_right_alt_is_pressed = false,
}

local is_dark = wezterm.gui.get_appearance():find("Dark")
local theme = utils.get_current_theme()

utils.table_extend(true, config, require(theme)(is_dark, assets))

return config
