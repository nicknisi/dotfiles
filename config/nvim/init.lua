-- init.lua
-- Neovim-specific configuration

-- Use the nisi config

local nisi = require("nisi")
nisi.setup({
  python = true,
  transparent = true,
  colorshceme = "tokyonight-night", -- Set the colorscheme to use
})
