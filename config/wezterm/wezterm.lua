local wezterm = require("wezterm")

local config = {
  color_scheme = "Catppuccin Mocha",
  window_background_opacity = 0.85,
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
      -- "#0f0c29",
      -- "#1e1e2d",
      -- "#302b63",
      "#00000C",
      -- "#00003F",
      "#000026",
      "#00000C",
      -- "#24243e",
      -- "#1e1e2d",
      -- "#0f0c29",
    },
    interpolation = "CatmullRom",
    blend = "Rgb",
    noise = 0,
  },
}

return config
