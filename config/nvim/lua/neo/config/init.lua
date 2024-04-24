local dotfiles = os.getenv("HOME") .. "/.config/dotfiles"
package.path = package.path .. ";" .. dotfiles .. "/?.lua;" .. dotfiles .. "/?/?.lua;" .. dotfiles .. "/?/init.lua"

local base_config = require("base.config")
local theme = require("base.theme")

local config = {
  -- the path to load lazy.nvim from
  -- It's useful to override this on systems where
  -- you want to keep the configuration consolidated
  lazypath = vim.fn.stdpath("data") .. "lazy/lazy.nvim",
  icons = theme.icons,
  colors = theme.colors,
}

-- mix in the base config
config = vim.tbl_deep_extend("force", config, base_config)

config["__merge"] = function(user_config)
  config = vim.tbl_deep_extend("force", config, user_config)
end

return config
