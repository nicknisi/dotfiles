local b = require("utils.background")
local h = require("utils.helpers")
local wezterm = require("wezterm")
local assets = wezterm.config_dir .. "/assets"
local config = wezterm.config_builder()

-- set this to true to enable fancy background
local fancy = false

config.macos_window_background_blur = 30
config.enable_tab_bar = false
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.native_macos_fullscreen_mode = true
config.window_padding = {
  left = 2,
  right = 2,
  top = 2,
  bottom = 2,
}

-- font config
config.font = wezterm.font("Monaspace Neon", { weight = "Regular" })
config.font_rules = {
  {
    italic = true,
    font = wezterm.font("Monaspace Radon", { weight = "Medium" }),
  },
}
config.harfbuzz_features = { "calt", "dlig", "clig=1", "ss01", "ss02", "ss03", "ss04", "ss05", "ss06", "ss07", "ss08" }
config.font_size = 16
config.line_height = 1.1
config.adjust_window_size_when_changing_font_size = false

-- keys config
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = false

if h.is_dark then
  config.color_scheme = "Catppuccin Mocha"
  config.set_environment_variables = {
    THEME_FLAVOUR = "mocha",
  }
  if fancy then
    config.background = {
      b.get_background(),
      b.get_animation(assets .. "/blob_blue.gif"),
    }
  end
else
  config.color_scheme = "Catppuccin Latte"
  config.window_background_opacity = 1
  config.set_environment_variables = {
    THEME_FLAVOUR = "latte",
  }
  config.background = {
    b.get_background(),
  }
end

return config
