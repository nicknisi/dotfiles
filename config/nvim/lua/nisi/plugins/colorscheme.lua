local config = require("nisi").config

return {
  -- Aether: the shared colorscheme for Omarchy-style themes.
  -- The palette comes from the active Omarchy theme (colors.toml on Linux)
  -- or from ~/.config/theme/current/nvim-aether.json on macOS.
  -- See apply_named_theme() in lua/nisi/init.lua for the loading logic.
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = config.transparent or false,
    },
  },
}
