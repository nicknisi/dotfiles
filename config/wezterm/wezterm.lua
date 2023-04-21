local wezterm = require("wezterm")

local config = {
  color_scheme = "Catppuccin Mocha",
  window_background_opacity = 0.9,
  enable_tab_bar = false,
  window_decorations = "RESIZE",
  font = wezterm.font("MonoLisa", { weight = "Medium" }),
  native_macos_fullscreen_mode = true,
  keys = {
    {
      key = "n",
      mods = "SHIFT|CTRL",
      action = wezterm.action.ToggleFullScreen,
    },
  },
  window_background_gradient = {
    orientation = "Horizontal",
    colors = {
      "#0f0c29",
      -- "#1e1e2d",
      "#302b63",
      -- "#24243e",
      "#1e1e2d",
    },
    interpolation = "CatmullRom",
    blend = "Rgb",
    noise = 0,
  },
}

return config
