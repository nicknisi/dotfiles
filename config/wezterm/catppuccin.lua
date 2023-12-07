return function(is_dark, assets)
  local config = {}

  if is_dark then
    config.color_scheme = "Catppuccin Mocha"
    config.window_background_opacity = 0.85
    -- config.background = {
    --   {
    --     source = {
    --       Gradient = {
    --         orientation = "Horizontal",
    --         colors = {
    --           "#00000C",
    --           "#000026",
    --           "#00000C",
    --         },
    --         interpolation = "CatmullRom",
    --         blend = "Rgb",
    --         noise = 0,
    --       },
    --     },
    --     width = "100%",
    --     height = "100%",
    --     opacity = 0.75,
    --   },
    --   {
    --     source = {
    --       File = { path = assets .. "/blob_blue.gif", speed = 0.3 },
    --     },
    --     repeat_x = "Mirror",
    --     -- width = "100%",
    --     height = "100%",
    --     opacity = 0.10,
    --     hsb = {
    --       hue = 0.9,
    --       saturation = 0.9,
    --       brightness = 0.8,
    --     },
    --   },
    -- }
  else
    config.color_scheme = "Catppuccin Latte"
    config.window_background_opacity = 1
    config.set_environment_variables = {
      THEME_FLAVOUR = "latte",
    }
  end

  return config
end
