local load_lazy = require("nisi.utils").load_lazy
local config = require("neo").config

local lazypath = config.lazypath or vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
load_lazy(lazypath)

local plugins = {
  { import = "nisi.plugins" },
}

if config.copilot then
  table.insert(plugins, { import = "nisi.plugins.extras.copilot" })
end

if config.astro then
  table.insert(plugins, { import = "nisi.plugins.extras.astro" })
end

if config.fzf then
  table.insert(plugins, { import = "nisi.plugins.extras.fzf" })
end

require("lazy").setup(plugins)
