local load_lazy = require("neo.utils").load_lazy
local config = require("neo.config")

local lazypath = config.lazypath or vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
load_lazy(lazypath)

local plugins = {
  { import = "neo.plugins" },
}

if config.copilot then
  table.insert(plugins, { import = "neo.plugins.extras.copilot" })
end

if config.astro then
  table.insert(plugins, { import = "neo.plugins.extras.astro" })
end

require("lazy").setup(plugins)
