local home = os.getenv("HOME")
local util = require("base.util")
local theme = require("base.theme")

local config = util.load_json(home .. "/dotfiles.json") or {}

-- the purpose of this file is to allow for an out-of-git way to set customized configuration for aesthetic things
-- like fonts, themes, etc.
-- Below are the default values for everything that will be read by neovim and wezterm. All of these values can be
-- overwritten by creating a ~/dotfiles.lua file and returning a configuration table with any/all of these overwritten
-- values.
local default_config = {
  -- these can be any
  font = {
    regular = "Monaspace Neon",
    italic = "Monaspace Radon",
  },
  art = nil,
  icons = theme.icons,
  colors = theme.colors,
  wallpaper = nil,
  copilot = false,
  astro = false,
  fzf = true,
  zen = false,
  lsp = {
    servers = {
      -- "eslint",
      -- "tsserver",
      "lua_ls",
      -- "denols",
      -- "astro",
      -- "tailwindcss",
      "jsonls",
      "vimls",
    },
  },
}

return util.table_extend(true, default_config, config)
