require("nisi.globals")
local icons = require("nisi.assets").icons
local utils = require("nisi.utils")

---The config for the Nisi Neovim setup
---@class NisiConfig
---@field lazypath string|nil The path to load lazy.nvim from
---@field startup_art NisiAscii|nil The startup art to show when loading the app
---@field startup_color string|nil The color to use for the startup art
---@field zen boolean|nil Whether to show a minimal UI (hide statusline, line numbers, etc.)
---@field copilot boolean|nil Whether copilot is enabled
---@field python boolean|nil Whether python is enabled
---@field avante boolean|nil Whether avante is enabled
---@field fzf boolean|nil Whether too configure fzf for tooling like telescope
---@field prefer_git boolean|nil Whether to prefer using git for dependencies over other options like curl
---@field proxy string|nil A proxy URL to use for certain network functions
---@field colorscheme string|fun()|nil What to set the colorscheme to and/or how
---@field transparent boolean|nil Whether to use a transparent background for the colorscheme
local config = {
  lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim",
  startup_art = "nicknisi",
  startup_color = "#653CAD",
  zen = false,
  copilot = true,
  avante = true,
  fzf = true,
  proxy = nil,
  prefer_git = false,
  colorscheme = function()
    if utils.is_dark_mode() then
      vim.o.background = "dark"
    else
      vim.o.background = "light"
    end

    vim.cmd("colorscheme catppuccin")
  end,
  transparent = false,
}

---Assign a user config to the config table
---@param user_config? NisiConfig
local function assign_config(user_config)
  if user_config then
    for k, v in pairs(user_config) do
      config[k] = v
    end
  end
end

---@class nisiConfig
local M = {}
local lazy_loaded = false
local setup_called = false

local function load_lazy(path)
  if not (vim.uv or vim.loop).fs_stat(path) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, path })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end
  vim.opt.rtp:prepend(path)
end

local plugins = {
  { import = "nisi.plugins" },
}

-- FIXME: fix the types
---@param plugin fun()|string|table
function M.add_plugin(plugin)
  table.insert(plugins, plugin)
end

---Load and configure neovim plugins using lazy.nvim
local function init_plugins()
  if lazy_loaded then
    return
  end

  local lazypath = config.lazypath or vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  load_lazy(lazypath)

  if config.copilot then
    M.add_plugin({ import = "nisi.plugins.extras.copilot" })
  end

  if config.python then
    M.add_plugin({ import = "nisi.plugins.extras.python" })
  end

  if config.avante then
    M.add_plugin({ import = "nisi.plugins.extras.avante" })
  end

  if config.fzf then
    M.add_plugin({ import = "nisi.plugins.extras.fzf" })
  end
  require("lazy").setup(plugins)

  lazy_loaded = true
end

---Apply syntax and LSP customizations
local function patch_syntax()
  -- set up custom symbols for LSP errors
  local signs = {
    Error = icons.error,
    Warning = icons.warning,
    Warn = icons.warning,
    Hint = icons.hint,
    Info = icons.hint,
  }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end

  vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = {
      current_line = true,
    },
    signs = true,
    update_in_insert = true,
    severity_sort = true,
  })

  -- make comments and HTML attributes italic
  -- vim.api.nvim_set_hl(0, "Comment", { italic = true })
  -- vim.api.nvim_set_hl(0, "htmlArg", { italic = true })
  -- vim.api.nvim_set_hl(0, "xmlAttrib", { italic = true })
  -- vim.cmd([[highlight Normal ctermbg=none]])
end

---Apply the colorscheme setting
---@param colorscheme string|fun() The colorscheme to apply
local function apply_colorscheme(colorscheme)
  if type(colorscheme) == "function" then
    colorscheme()
  else
    vim.cmd("colorscheme " .. colorscheme)
  end
end

---@param user_config? NisiConfig
function M.setup(user_config)
  if setup_called then
    -- only call setup once
    return
  end

  assign_config(user_config)
  if config.proxy then
    -- Set proxy environment variables for Neovim
    vim.env.http_proxy = config.proxy
    vim.env.https_proxy = config.proxy
  end

  require("nisi.config.filetype")
  require("nisi.config.options")
  require("nisi.config.keymaps")
  init_plugins()

  -- do these sctions after initializing the plugins
  apply_colorscheme(config.colorscheme)
  vim.cmd.syntax("on")
  vim.cmd("filetype plugin indent on")
  patch_syntax()
end

M.config = config

return M
