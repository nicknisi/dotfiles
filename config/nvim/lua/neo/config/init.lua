local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
package.path = package.path .. ";" .. dotfiles .. "/?.lua;" .. dotfiles .. "/?/?.lua;" .. dotfiles .. "/?/init.lua"

local base_config = require("base.config")
local theme = require("base.theme")
local util = require("base.util")

local M = {
  -- the path to load lazy.nvim from
  -- It's useful to override this on systems where
  -- you want to keep the configuration consolidated
  lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim",
  icons = theme.icons,
  colors = theme.colors,
}

util.table_extend(true, M, base_config)

return M
