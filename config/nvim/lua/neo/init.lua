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

---@class NisiConfigOptions
---@field lazypath string|nil The path to load lazy.nvim from
---@field art StartupHeader|nil The startup art to show when loading the app
---@field zen boolean|nil Whether to show a minimal UI (hide statusline, line numbers, etc.)
---@field copilot boolean|nil Whether copilot is enabled
---@field fzf boolean|nil Whether too configure fzf for tooling like telescope
---@field git boolean|nil Whether or not to configure the dotfiles for git
local default_options = {
  lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim",
  art = "meatboy",
  zen = false,
  copilot = true,
  fzf = true,
  git = true,
}

---@type NisiConfigOptions
local config = {}

for _, path in ipairs(paths) do
  utils.add_path(path)
end

-- this must be loaded after the above path additions
local icons = require("neo.config").icons

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

---Load and configure neovim plugins using lazy.nvim
local function init_plugins()
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

  -- if config.astro then
  --   table.insert(plugins, { import = "neo.plugins.extras.astro" })
  -- end

  if config.fzf then
    table.insert(plugins, { import = "neo.plugins.extras.fzf" })
  end
  require("lazy").setup(plugins)

  lazy_loaded = true
end

---Apply syntax and LSP customizations
local function patch_syntax()
  -- set up custom symbols for LSP errors
  local signs =
    { Error = icons.bug, Warning = icons.warning, Warn = icons.warning, Hint = icons.hint, Info = icons.hint }
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
end

---Configure Neovim based on nicknisi/dotfiles
---@param user_config? NisiConfigOptions
function M.setup(user_config)
  if setup_called then
    -- only call setup once
    return
  end

  vim.tbl_deep_extend("force", config, default_options, user_config)
  require("neo.config.options")
  require("neo.config.keymaps")
  init_plugins()
  vim.cmd.syntax("on")
  vim.cmd("filetype plugin indent on")
  patch_syntax()
end

M.config = config

return M
