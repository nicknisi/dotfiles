local config = require("nisi").config
local ascii = require("nisi.assets").ascii

-- if in a git directory, open git files, otherwise open all files when pressing the "Find File" shortcut
local find_command = vim.fs.root(vim.fn.getcwd(), ".git") and ":Telescope git_files" or ":Telescope find_files"

---@module 'snacks'

return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    dashboard = {
      enabled = true,
      preset = {
        header = table.concat(ascii[config.startup_art] or ascii.meatboy, "\n"),
        ---@type snacks.dashboard.Item[]
        keys = {
          { icon = " ", key = "t", desc = "Find File", action = find_command },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { pane = 2, section = "keys" },
        {
          pane = 2,
          icon = " ",
          desc = "Browse Repo",
          padding = 1,
          key = "b",
          action = function()
            Snacks.gitbrowse()
          end,
        },
        {
          pane = 2,
          section = "terminal",
          icon = " ",
          title = "Git Status",
          cmd = "git --no-pager diff --stat -B -M -C",
          height = 10,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
        },
        { section = "startup" },
      },
    },
  },
}
