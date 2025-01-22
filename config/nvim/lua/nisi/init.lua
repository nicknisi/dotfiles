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
---@field avante boolean|nil Whether avante is enabled
---@field fzf boolean|nil Whether too configure fzf for tooling like telescope
---@field prefer_git boolean|nil Whether to prefer using git for dependencies over other options like curl
---@field proxy string|nil A proxy URL to use for certain network functions
---@field colorscheme string|fun()|nil What to set the colorscheme to and/or how
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
    signs = true,
    update_in_insert = true,
    severity_sort = true,
  })

  -- make comments and HTML attributes italic
  vim.cmd([[highlight Comment cterm=italic term=italic gui=italic]])
  vim.cmd([[highlight htmlArg cterm=italic term=italic gui=italic]])
  vim.cmd([[highlight xmlAttrib cterm=italic term=italic gui=italic]])
  vim.cmd([[highlight Normal ctermbg=none]])
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

  -- @TODO seems like it's not the right place for smart-splits setup, but it has to be after init_plugins
  require("smart-splits").setup({
    -- Ignored buffer types (only while resizing)
    ignored_buftypes = {
      "nofile",
      "quickfix",
      "prompt",
    },
    -- Ignored filetypes (only while resizing)
    ignored_filetypes = { "NvimTree" },
    -- the default number of lines/columns to resize by at a time
    default_amount = 3,
    -- Desired behavior when your cursor is at an edge and you
    -- are moving towards that same edge:
    -- 'wrap' => Wrap to opposite side
    -- 'split' => Create a new split in the desired direction
    -- 'stop' => Do nothing
    -- function => You handle the behavior yourself
    -- NOTE: If using a function, the function will be called with
    -- a context object with the following fields:
    -- {
    --    mux = {
    --      type:'tmux'|'wezterm'|'kitty'
    --      current_pane_id():number,
    --      is_in_session(): boolean
    --      current_pane_is_zoomed():boolean,
    --      -- following methods return a boolean to indicate success or failure
    --      current_pane_at_edge(direction:'left'|'right'|'up'|'down'):boolean
    --      next_pane(direction:'left'|'right'|'up'|'down'):boolean
    --      resize_pane(direction:'left'|'right'|'up'|'down'):boolean
    --      split_pane(direction:'left'|'right'|'up'|'down',size:number|nil):boolean
    --    },
    --    direction = 'left'|'right'|'up'|'down',
    --    split(), -- utility function to split current Neovim pane in the current direction
    --    wrap(), -- utility function to wrap to opposite Neovim pane
    -- }
    -- NOTE: `at_edge = 'wrap'` is not supported on Kitty terminal
    -- multiplexer, as there is no way to determine layout via the CLI
    at_edge = "split",
    -- Desired behavior when the current window is floating:
    -- 'previous' => Focus previous Vim window and perform action
    -- 'mux' => Always forward action to multiplexer
    float_win_behavior = "previous",
    -- when moving cursor between splits left or right,
    -- place the cursor on the same row of the *screen*
    -- regardless of line numbers. False by default.
    -- Can be overridden via function parameter, see Usage.
    move_cursor_same_row = false,
    -- whether the cursor should follow the buffer when swapping
    -- buffers by default; it can also be controlled by passing
    -- `{ move_cursor = true }` or `{ move_cursor = false }`
    -- when calling the Lua function.
    cursor_follows_swapped_bufs = false,
    -- resize mode options
    resize_mode = {
      -- key to exit persistent resize mode
      quit_key = "<ESC>",
      -- keys to use for moving in resize mode
      -- in order of left, down, up' right
      resize_keys = { "h", "j", "k", "l" },
      -- set to true to silence the notifications
      -- when entering/exiting persistent resize mode
      silent = false,
      -- must be functions, they will be executed when
      -- entering or exiting the resize mode
      hooks = {
        on_enter = nil,
        on_leave = nil,
      },
    },
    -- ignore these autocmd events (via :h eventignore) while processing
    -- smart-splits.nvim computations, which involve visiting different
    -- buffers and windows. These events will be ignored during processing,
    -- and un-ignored on completed. This only applies to resize events,
    -- not cursor movement events.
    ignored_events = {
      "BufEnter",
      "WinEnter",
    },
    -- enable or disable a multiplexer integration;
    -- automatically determined, unless explicitly disabled or set,
    -- by checking the $TERM_PROGRAM environment variable,
    -- and the $KITTY_LISTEN_ON environment variable for Kitty
    multiplexer_integration = nil,
    -- disable multiplexer navigation if current multiplexer pane is zoomed
    -- this functionality is only supported on tmux and Wezterm due to kitty
    -- not having a way to check if a pane is zoomed
    disable_multiplexer_nav_when_zoomed = true,
    -- default logging level, one of: 'trace'|'debug'|'info'|'warn'|'error'|'fatal'
    log_level = "info",
  })

  vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left)
  vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down)
  vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up)
  vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right)
  vim.keymap.set("n", "<C-\\>", require("smart-splits").move_cursor_previous)

  -- do these sctions after initializing the plugins
  apply_colorscheme(config.colorscheme)
  vim.cmd.syntax("on")
  vim.cmd("filetype plugin indent on")
  patch_syntax()
end

M.config = config

return M
