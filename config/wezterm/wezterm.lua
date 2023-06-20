local wezterm = require("wezterm")

local wezdir = os.getenv("HOME") .. "/.config/wezterm"

local config = {
  color_scheme = "Catppuccin Macchiato",
  window_background_opacity = 0.85,
  enable_tab_bar = false,
  window_decorations = "RESIZE",
  font = wezterm.font("Rec Mono Duotone", { weight = "Medium" }),
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
}

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
    opacity = 0.85,
  },
  -- {
  --   source = {
  --     File = { path = wezdir .. "/dvd.gif" },
  --   },
  --   repeat_y = "Mirror",
  --   width = "100%",
  --   opacity = 0.42,
  --   hsb = {
  --     -- hue = 0.6,
  --     -- saturation = 0.9,
  --     brightness = 0.2,
  --   },
  --   horizontal_align = "Right",
  --   attachment = { Parallax = 0.2 },
  -- },
  {
    source = {
      File = { path = wezdir .. "/4.gif", speed = 0.4 },
    },
    repeat_y = "Mirror",
    width = "100%",
    opacity = 0.15,
    hsb = {
      hue = 0.6,
      saturation = 0.9,
      brightness = 0.1,
    },
  },
  {
    source = {
      File = { path = wezdir .. "/pulsing.gif", speed = 0.4 },
    },
    repeat_y = "Mirror",
    width = "100%",
    opacity = 0.05,
    hsb = {
      hue = 0.6,
      saturation = 0.9,
      brightness = 0.1,
    },
  },
  -- {
  --   source = {
  --     File = { path = wezdir .. "/cage.jpg" },
  --   },
  --   repeat_y = "Mirror",
  --   width = "100%",
  --   opacity = 0.18,
  --   hsb = {
  --     brightness = 0.2,
  --   },
  -- },
}

return config
