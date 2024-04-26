-- init.lua
-- Neovim-specific configuration

require("globals")

-- start using the neo (temp name) config
local neo = require("neo")
neo.setup({
  copilot = false,
})

local icons = require("neo.config").icons

if require("base.util").is_dark_mode() then
  vim.g.catppuccin_flavour = "mocha"
  vim.o.background = "dark"
else
  vim.g.catppuccin_flavour = "latte"
  vim.o.background = "light"
end

-- vim.command.colorscheme "catppuccin"
vim.cmd("colorscheme catppuccin")

-- set up custom symbols for LSP errors
local signs = { Error = icons.bug, Warning = icons.warning, Warn = icons.warning, Hint = icons.hint, Info = icons.hint }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.diagnostic.config({ virtual_text = true, signs = true, update_in_insert = true, severity_sort = true })

-- make comments and HTML attributes italic
vim.cmd([[highlight Comment cterm=italic term=italic gui=italic]])
vim.cmd([[highlight htmlArg cterm=italic term=italic gui=italic]])
vim.cmd([[highlight xmlAttrib cterm=italic term=italic gui=italic]])
vim.cmd([[highlight Normal ctermbg=none]])
