return function(is_dark)
  local config = {}

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

  return config
end
