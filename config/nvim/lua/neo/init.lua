local config = require("neo.config")
local utils = require("neo.utils")

local M = {}
local lazy_loaded = false
local setup_called = false
local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
local paths = {
  dotfiles .. "/?.lua",
  dotfiles .. "/?/?.lua",
  dotfiles .. "/?/init.lua",
}

for _, path in ipairs(paths) do
  utils.add_path(path)
end

local function load_lazy(path)
  if not vim.loop.fs_stat(path) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      path,
    })
  end
  vim.opt.rtp:prepend(path)
end

function M.setup(user_config)
  if setup_called then
    return
  end

  config.__merge(user_config)
  require("neo.config.options")
  require("neo.config.keymaps")
end

function M.init_plugins()
  if lazy_loaded then
    return
  end

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

  if config.fzf then
    table.insert(plugins, { import = "neo.plugins.extras.fzf" })
  end
  require("lazy").setup(plugins)

  lazy_loaded = true
end

return M
