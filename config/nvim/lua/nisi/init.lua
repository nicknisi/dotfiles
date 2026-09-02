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
---@field fzf boolean|nil Whether too configure fzf for tooling like telescope
---@field prefer_git boolean|nil Whether to prefer using git for dependencies over other options like curl
---@field proxy string|nil A proxy URL to use for certain network functions
---@field colorscheme string|fun()|nil What to set the colorscheme to and/or how
---@field transparent boolean|nil Whether to use a transparent background for the colorscheme
---@field snippets_dir string|nil The directory to load snippets from
local config = {
  lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim",
  startup_art = "nicknisi",
  startup_color = "#653CAD",
  zen = false,
  copilot = true,
  fzf = true,
  proxy = nil,
  prefer_git = false,
  colorscheme = function()
    _G.apply_named_theme()
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

  if config.fzf then
    M.add_plugin({ import = "nisi.plugins.extras.fzf" })
  end
  require("lazy").setup(plugins)

  lazy_loaded = true
end

---Apply syntax and LSP customizations
local function patch_syntax()
  -- set up custom symbols for LSP errors
  vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = {
      current_line = true,
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.error,
        [vim.diagnostic.severity.WARN] = icons.warning,
        [vim.diagnostic.severity.HINT] = icons.hint,
        [vim.diagnostic.severity.INFO] = icons.hint,
      },
    },
    update_in_insert = true,
    severity_sort = true,
  })

  -- make comments and HTML attributes italic
  -- vim.api.nvim_set_hl(0, "Comment", { italic = true })
  -- vim.api.nvim_set_hl(0, "htmlArg", { italic = true })
  -- vim.api.nvim_set_hl(0, "xmlAttrib", { italic = true })
  -- vim.cmd([[highlight Normal ctermbg=none]])
end

---Parse an Omarchy colors.toml into an aether-compatible palette table.
---@param path string Path to the colors.toml file
---@return table|nil palette The aether colors table, or nil if the file can't be read
local function parse_omarchy_colors(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local raw = {}
  for line in file:lines() do
    local key, val = line:match('^([%w_]+)%s*=%s*"(.-)"')
    if key and val then
      raw[key] = val
    end
  end
  file:close()

  return {
    bg = raw.background,
    dark_bg = raw.dark_background,
    darker_bg = raw.darker_background,
    lighter_bg = raw.lighter_background,
    fg = raw.foreground,
    dark_fg = raw.dark_foreground,
    light_fg = raw.light_foreground,
    bright_fg = raw.bright_foreground,
    muted = raw.muted,
    red = raw.red,
    yellow = raw.yellow,
    orange = raw.orange,
    green = raw.green,
    cyan = raw.cyan,
    blue = raw.blue,
    magenta = raw.magenta,
    brown = raw.brown,
    bright_red = raw.bright_red,
    bright_yellow = raw.bright_yellow,
    bright_green = raw.bright_green,
    bright_cyan = raw.bright_cyan,
    bright_blue = raw.bright_blue,
    bright_magenta = raw.bright_magenta,
    accent = raw.accent,
    cursor = raw.bright_foreground,
    foreground = raw.foreground,
    background = raw.background,
    selection = raw.selection,
    selection_foreground = raw.selection_foreground,
    selection_background = raw.selection_background,
  }
end

---Re-apply the active theme.
---On Omarchy (Linux) this reads ~/.local/state/omarchy/current/theme/colors.toml
---and feeds the palette into aether.
---On macOS it falls back to ~/.config/theme/current/nvim-aether.json (managed
---by bin/theme) or uses aether's default palette.
function _G.apply_named_theme()
  local mode = utils.is_dark_mode() and "dark" or "light"
  vim.o.background = mode

  local omarchy_colors = parse_omarchy_colors(vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml"))
  if omarchy_colors then
    require("aether").setup({ colors = omarchy_colors })
  else
    -- macOS fallback: bin/theme writes an nvim-aether.json palette
    local macos_palette = vim.fn.expand("~/.config/theme/current/nvim-aether.json")
    if (vim.uv or vim.loop).fs_stat(macos_palette) then
      require("aether").setup({
        colors = vim.json.decode(table.concat(vim.fn.readfile(macos_palette), "\n")),
      })
    end
  end

  vim.cmd("colorscheme aether")
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
