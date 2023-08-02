local wezterm = require("wezterm")

local wezdir = os.getenv("HOME") .. "/.config/wezterm"

local config = {
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
      opacity = 0.75,
    },
    -- {
    --   source = {
    --     File = {
    --       path = wezdir .. "/lines.gif",
    --       speed = 0.40,
    --     },
    --   },
    --   repeat_y = "Mirror",
    --   width = "100%",
    --   -- height = "100%",
    --   opacity = 0.25,
    --   hsb = {
    --     hue = 0.2,
    --     saturation = 0.2,
    --     brightness = 0.01,
    --   },
    -- },
    {
      source = {
        File = { path = wezdir .. "/blob_blue.gif", speed = 0.3 },
      },
      repeat_x = "Mirror",
      -- width = "100%",
      height = "100%",
      opacity = 0.10,
      hsb = {
        hue = 0.9,
        saturation = 0.9,
        brightness = 0.3,
      },
    },
    -- {
    --   source = {
    --     File = { path = wezdir .. "/blob.gif", speed = 0.3 },
    --   },
    --   repeat_x = "Mirror",
    --   -- width = "100%",
    --   height = "100%",
    --   opacity = 0.20,
    --   hsb = {
    --     hue = 0.5,
    --     saturation = 0.9,
    --     brightness = 0.2,
    --   },
    -- },
  }
else
  config.color_scheme = "Catppuccin Latte"
  config.window_background_opacity = 1
  config.set_environment_variables = {
    THEME_FLAVOUR = "latte",
  }
end

return config
