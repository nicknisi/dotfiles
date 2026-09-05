local config = require("nisi").config

return {
  -- Aether: the one colorscheme; bin/theme renders each pack's palette to
  -- ~/.local/state/theme/current/theme/nvim-aether.json.
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
