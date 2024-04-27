-- init.lua
-- Neovim-specific configuration

require("globals")

-- start using the neo (temp name) config
local stalwart = require("stalwart")
stalwart.setup({
  copilot = false,
})

if require("base.util").is_dark_mode() then
  vim.g.catppuccin_flavour = "mocha"
  vim.o.background = "dark"
else
  vim.g.catppuccin_flavour = "latte"
  vim.o.background = "light"
end

-- vim.command.colorscheme "catppuccin"
vim.cmd("colorscheme catppuccin")
