-- configure wezterm to use the ~/.config/dotfiles directory for shared lua modules
local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
package.path = package.path .. ";" .. dotfiles .. "/?.lua;" .. dotfiles .. "/?/?.lua;" .. dotfiles .. "/?/init.lua"

local b = require("utils.background")
local custom_config = require("base.config")
local h = require("utils.helpers")
local wezterm = require("wezterm")

local theme = custom_config.theme or b.get_default_theme()
local assets = wezterm.config_dir .. "/assets"

local config = {
  macos_window_background_blur = 30,
  enable_tab_bar = false,
  window_decorations = "RESIZE",
  window_close_confirmation = "NeverPrompt",
  native_macos_fullscreen_mode = true,
  window_padding = {
    left = 2,
    right = 2,
    top = 2,
    bottom = 2,
  },

  -- font config
  font = wezterm.font(custom_config.font.regular, { weight = "Regular" }),
  font_rules = {
    {
      italic = true,
      font = wezterm.font(custom_config.font.italic, { weight = "Medium" }),
    },
  },
  harfbuzz_features = { "calt", "dlig", "clig=1", "ss01", "ss02", "ss03", "ss04", "ss05", "ss06", "ss07", "ss08" },
  font_size = 16,
  line_height = 1.1,
  adjust_window_size_when_changing_font_size = false,

  -- keys config
  send_composed_key_when_left_alt_is_pressed = true,
  send_composed_key_when_right_alt_is_pressed = false,
}

if h.is_dark then
  config.color_scheme = theme
  config.set_environment_variables = {
    THEME_FLAVOUR = "mocha",
  }
  config.background = {
    -- custom_config.wallpaper_dir and b.get_random_wallpaper(custom_config.wallpaper_dir .. "/*.{png,jpg,jpeg}") or {},
    -- b.get_random_animation(assets .. "/*.gif"),
    b.get_background(),
  }

  if custom_config["wallpaper"] ~= nil then
    table.insert(config.background, 1, b.get_random_wallpaper(custom_config.wallpaper .. "/*.{png,jpg,jpeg}"))
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
