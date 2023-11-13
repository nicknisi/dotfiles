local wezterm = require("wezterm")

local assets = wezterm.config_dir .. "/assets"

local function get_current_theme()
  local file = io.open(os.getenv("HOME") .. "/.theme", "r")

  if not file then
    return "catppuccin"
  end

  local content = file:read("*a")
  file:close()

  content = content:gsub("%s+", "")

  return content
end

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
  -- font = wezterm.font("Rec Mono Duotone", { weight = "Regular" }),
  -- font = wezterm.font("MonoLisa", { weight = "Regular" }),
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

local appearance = wezterm.gui.get_appearance()
local is_dark = appearance:find("Dark")
local theme = get_current_theme()

if theme == "catppuccin" then
  if is_dark then
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
      {
        source = {
          File = { path = assets .. "/blob_blue.gif", speed = 0.3 },
        },
        repeat_x = "Mirror",
        -- width = "100%",
        height = "100%",
        opacity = 0.10,
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
elseif theme == "everforest" then
  if is_dark then
    config.color_scheme = "Everforest Dark (Gogh)"
    config.window_background_opacity = 1
    config.background = {
      {
        source = {
          Gradient = {
            orientation = "Horizontal",
            colors = {
              "#2f394e",
              -- "#5864fc",
              -- "#daa520",
              "#2f393c",
            },
            interpolation = "CatmullRom",
            blend = "Rgb",
            noise = 0,
          },
        },
        width = "100%",
        height = "100%",
        opacity = 1,
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
    config.color_scheme = "Everforest Light (Gogh)"
  end
elseif theme == "tokyonight" then
  if is_dark then
    config.color_scheme = "tokyonight-storm"
    config.window_background_opacity = 0.90
    -- config.background = {
    --   {
    --     source = {
    --       Gradient = {
    --         orientation = { Linear = { angle = -45.0 } },
    --         colors = {
    --           "#000000",
    --           "#000000",
    --           "#0d3b66",
    --           "#000000",
    --           "#0d3b66",
    --           -- "#843b62",
    --           "#000000",
    --         },
    --         interpolation = "Basis",
    --         blend = "LinearRgb",
    --         noise = 0,
    --       },
    --     },
    --     width = "100%",
    --     height = "100%",
    --     opacity = 0.85,
    --   },
    --   {
    --     source = {
    --       File = { path = assets .. "/blob_blue.gif", speed = 0.3 },
    --     },
    --     repeat_x = "Mirror",
    --     -- width = "100%",
    --     height = "100%",
    --     opacity = 0.05,
    --     hsb = {
    --       hue = 0.9,
    --       saturation = 0.9,
    --       brightness = 0.8,
    --     },
    --   },
    -- }
  else
    config.color_scheme = "tokyonight-day"
  end
end

return config
