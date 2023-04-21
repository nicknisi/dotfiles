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
}

config.window_background_gradient = {
  -- Can be "Vertical" or "Horizontal".  Specifies the direction
  -- in which the color gradient varies.  The default is "Horizontal",
  -- with the gradient going from left-to-right.
  -- Linear and Radial gradients are also supported; see the other
  -- examples below
  orientation = "Horizontal",

  -- Specifies the set of colors that are interpolated in the gradient.
  -- Accepts CSS style color specs, from named colors, through rgb
  -- strings and more
  colors = {
    "#0f0c29",
    "#302b63",
    "#24243e",
  },

  -- Instead of specifying `colors`, you can use one of a number of
  -- predefined, preset gradients.
  -- A list of presets is shown in a section below.
  -- preset = "Warm",

  -- Specifies the interpolation style to be used.
  -- "Linear", "Basis" and "CatmullRom" as supported.
  -- The default is "Linear".
  interpolation = "CatmullRom",

  -- How the colors are blended in the gradient.
  -- "Rgb", "LinearRgb", "Hsv" and "Oklab" are supported.
  -- The default is "Rgb".
  blend = "Rgb",

  -- To avoid vertical color banding for horizontal gradients, the
  -- gradient position is randomly shifted by up to the `noise` value
  -- for each pixel.
  -- Smaller values, or 0, will make bands more prominent.
  -- The default value is 64 which gives decent looking results
  -- on a retina macbook pro display.
  noise = 0,

  -- By default, the gradient smoothly transitions between the colors.
  -- You can adjust the sharpness by specifying the segment_size and
  -- segment_smoothness parameters.
  -- segment_size configures how many segments are present.
  -- segment_smoothness is how hard the edge is; 0.0 is a hard edge,
  -- 1.0 is a soft edge.

  -- segment_size = 11,
  -- segment_smoothness = 1.0,
}

return config
