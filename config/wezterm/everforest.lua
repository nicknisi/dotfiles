return function(is_dark, assets)
  local config = {}

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

  return config
end
