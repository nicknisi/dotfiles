return function(is_dark, assets)
  local config = {}

  if is_dark then
    -- config.color_scheme = "Nord (Gogh)"
    config.color_scheme = "Nocturnal Winter"
    config.window_background_opacity = 0.90
  else
    config.color_scheme = "Nord Light (Gogh)"
    config.window_background_opacity = 1
    config.set_environment_variables = {
      THEME_FLAVOUR = "latte",
    }
  end

  return config
end
