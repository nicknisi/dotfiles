local wezterm = require("wezterm")

local assets = wezterm.config_dir .. "/assets"

local config = {
  -- window_background_opacity = 0.15,
  macos_window_background_blur = 30,
  enable_tab_bar = false,
  window_decorations = "RESIZE",
  font = wezterm.font("Rec Mono Duotone", { weight = "Regular" }),
  -- font = wezterm.font("MonoLisa", { weight = "Medium" }),
  font_size = 16,
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

local appearance = wezterm.gui.get_appearance()

if appearance:find("Dark") then
  config.color_scheme = "Catppuccin Mocha"
  config.background = {
    {
      source = {
        Gradient = {
          orientation = "Horizontal",
          colors = {
            "#00000C",
            "#000026",
            "#00000C",
          },
          interpolation = "CatmullRom",
          blend = "Rgb",
          noise = 0,
        },
      },
      width = "100%",
      height = "100%",
      opacity = 0.55,
    },
    {
      source = {
        File = { path = assets .. "/blob_blue.gif", speed = 0.3 },
      },
      repeat_x = "Mirror",
      -- width = "100%",
      height = "100%",
      opacity = 0.05,
      hsb = {
        hue = 0.9,
        saturation = 0.9,
        brightness = 0.8,
      },
    },
  }
else
  config.color_scheme = "Catppuccin Latte"
  config.window_background_opacity = 1
  config.set_environment_variables = {
    THEME_FLAVOUR = "latte",
  }
end

return config
