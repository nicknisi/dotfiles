local b = require("utils.background")
local h = require("utils.helpers")
local wezterm = require("wezterm")
local assets = wezterm.config_dir .. "/assets"
local config = wezterm.config_builder()

-- set this to true to enable fancy background
local fancy = true

config.max_fps = 120
config.prefer_egl = true

config.colors = {
  cursor_bg = "#f5c06f",
  cursor_border = "#f5c06f",
  indexed = { [239] = "lightslategray" },
}

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
config.font = wezterm.font("Monaspace Neon", { weight = "Regular" })
config.font_rules = {
  {
    intensity = "Normal",
    italic = true,
    font = wezterm.font("Monaspace Radon", { weight = "Regular" }),
  },
  {
    intensity = "Bold",
    italic = false,
    font = wezterm.font("Monaspace Neon", { weight = "ExtraBold" }),
  },
  {
    intensity = "Bold",
    italic = true,
    font = wezterm.font("Monaspace Radon", { weight = "ExtraBold" }),
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
  -- local custom = wezterm.color.get_builtin_schemes()["Catppuccin Macchiato"]
  -- -- set a custom, darker background color for Macchiato
  -- custom.background = "#0b0b12"

  -- override the Catppuccin Macchiato color scheme
  -- config.color_schemes = {
  --   ["Catppuccin Macchiato"] = custom,
  -- }

  -- and use the custom color scheme
  -- config.color_scheme = "Catppuccin Macchiato"
  config.color_scheme = "Catppuccin Macchiato"
  config.set_environment_variables = {
    THEME_FLAVOUR = "macchiato",
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

wezterm.plugin.require("https://gitlab.com/xarvex/presentation.wez").apply_to_config(config)

return config
