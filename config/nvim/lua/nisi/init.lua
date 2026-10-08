local icons = require("nisi.assets").icons
local utils = require("nisi.utils")

---The config for the Nisi Neovim setup
---@class NisiConfig
---@field lazypath string|nil The path to load lazy.nvim from
---@field startup_art NisiAscii|nil The startup art to show when loading the app
---@field copilot boolean|nil Whether copilot is enabled
---@field python boolean|nil Whether python is enabled
---@field fzf boolean|nil Whether to use the native fzf sorter in telescope
---@field transparent boolean|nil Whether to use a transparent background for the colorscheme
local config = {
  lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim",
  startup_art = "nicknisi",
  copilot = true,
  fzf = true,
  transparent = true,
}

local M = {}
local setup_called = false

local function load_lazy(path)
  if not vim.uv.fs_stat(path) then
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

---Load and configure neovim plugins using lazy.nvim
local function init_plugins()
  load_lazy(config.lazypath)

  local plugins = { { import = "nisi.plugins" } }
  for _, extra in ipairs({ "copilot", "python", "fzf" }) do
    if config[extra] then
      table.insert(plugins, { import = "nisi.plugins.extras." .. extra })
    end
  end
  require("lazy").setup(plugins)
end

---Re-apply the active theme.
---bin/theme renders the pack's palette to ~/.local/state/theme/current/theme/
---nvim-aether.json (Linux and macOS alike) and writes dark|light to
---~/.local/state/theme/current/mode; both are read fresh on every call, so a
---switch can drive this over --remote-expr and a running nvim retints.
function _G.apply_named_theme()
  vim.o.background = utils.is_dark_mode() and "dark" or "light"

  local palette = vim.fn.expand("~/.local/state/theme/current/theme/nvim-aether.json")
  if vim.uv.fs_stat(palette) then
    local ok, colors = pcall(vim.json.decode, table.concat(vim.fn.readfile(palette), "\n"))
    if ok and type(colors) == "table" then
      require("aether").setup({ colors = colors, transparent = config.transparent })
    end
  end

  vim.cmd("colorscheme aether")
end

---@param user_config? NisiConfig
function M.setup(user_config)
  if setup_called then
    return
  end
  setup_called = true

  config = vim.tbl_extend("force", config, user_config or {})
  M.config = config

  require("nisi.config.filetype")
  require("nisi.config.options")
  require("nisi.config.keymaps")
  init_plugins()

  _G.apply_named_theme()
  vim.diagnostic.config({
    virtual_text = true,
    virtual_lines = { current_line = true },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.error,
        [vim.diagnostic.severity.WARN] = icons.warning,
        [vim.diagnostic.severity.HINT] = icons.hint,
        [vim.diagnostic.severity.INFO] = icons.hint,
      },
    },
    float = { source = "if_many", header = "", prefix = "" },
    update_in_insert = true,
    severity_sort = true,
  })
end

M.config = config

return M
