local h = require("utils.helpers")
local wezterm = require("wezterm")
local M = {}

M.get_default_theme = function()
  return h.is_dark and "Catppuccin Mocha" or "Catppuccin Latte"
end

M.get_background = function(dark, light)
  dark = dark or 0.65
  light = light or 0.9

  return {
    source = {
      Gradient = {
        colors = { h.is_dark and "#000000" or "#ffffff" },
      },
    },
    width = "100%",
    height = "100%",
    opacity = h.is_dark and dark or light,
  }
end

M.get_wallpaper = function(wallpaper)
  return {
    source = { File = { path = wallpaper } },
    height = "Cover",
    width = "Cover",
    horizontal_align = "Center",
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
    opacity = 1,
  }
end

M.get_random_wallpaper = function(dir)
  dir = dir or os.getenv("HOME") .. "/.config/wezterm/assets/***.{jpg,jpeg,png}"
  local wallpapers = {}
  for _, v in ipairs(wezterm.glob(dir)) do
    if not string.match(v, "%.DS_Store$") then
      table.insert(wallpapers, v)
    end
  end

  local wallpaper = h.get_random_entry(wallpapers)

  return M.get_wallpaper(wallpaper)
end

M.get_animation = function(animation)
  return {
    source = {
      File = {
        path = animation,
        speed = 0.001,
      },
    },
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
    vertical_align = "Middle",
    width = "100%",
    height = "Cover",
    opacity = 0.45,
    hsb = {
      hue = 0.9,
      saturation = 0.8,
      brightness = 0.1,
    },
  }
end

M.get_random_animation = function(dir)
  dir = dir or os.getenv("HOME") .. "/.config/wezterm/assets"
  local animations = {}
  for _, v in ipairs(wezterm.glob(dir)) do
    if not string.match(v, "%.DS_Store$") then
      table.insert(animations, v)
    end
  end

  local animation = h.get_random_entry(animations)

  return M.get_animation(animation)
end

return M
