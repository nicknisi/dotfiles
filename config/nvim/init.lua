-- init.lua
-- Neovim-specific configuration

-- add
-- configure wezterm to use the ~/.config/dotfiles directory for shared lua modules
local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
package.path = package.path .. ";" .. dotfiles .. "/?.lua;" .. dotfiles .. "/?/?.lua;" .. dotfiles .. "/?/init.lua"
-- start using the neo (temp name) config
require("neo.config.options")
require("neo.config.keymaps")
require("neo.config.lazy")

require("globals")
local cmd = vim.cmd
local fn = vim.fn
local utils = require("neo.utils")
local termcodes = utils.termcodes
local config = require("base.config")
local icons = config.icons

-- create a completion_nvim table on _G which is visible via
-- v:lua from vimscript
_G.completion_nvim = {}

function _G.completion_nvim.smart_pumvisible(vis_seq, not_vis_seq)
  if fn.pumvisible() == 1 then
    return termcodes(vis_seq)
  else
    return termcodes(not_vis_seq)
  end
end

cmd([[syntax on]])
cmd([[filetype plugin indent on]])

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
cmd([[highlight Comment cterm=italic term=italic gui=italic]])
cmd([[highlight htmlArg cterm=italic term=italic gui=italic]])
cmd([[highlight xmlAttrib cterm=italic term=italic gui=italic]])
cmd([[highlight Normal ctermbg=none]])

vim.cmd([[
  command! Lint lua Lint()
]])

function _G.Lint()
  local command = vim.fn.input("Enter command: ")
  local current_efm = vim.o.errorformat

  vim.o.errorformat = "%f:%l:%c:%m"

  local output = vim.fn.system(command) or ""

  local lines = vim.split(output, "\n")
  local qf_list = {}
  for _, line in ipairs(lines) do
    local file, line_no, column, msg = string.match(line, "(.+):(%d+):(%d+):(.+)")
    if file then
      table.insert(qf_list, { filename = file, lnum = line_no, col = column, text = msg })
    end
  end

  if #qf_list > 0 then
    vim.fn.setqflist(qf_list)
    vim.cmd("cwindow")
  end

  vim.o.errorformat = current_efm
end
