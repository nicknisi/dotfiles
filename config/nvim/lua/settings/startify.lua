local nmap = require("utils").nmap
local g = vim.g
local fn = vim.fn

g.startify_files_number = 10
g.startify_change_to_dir = 0
local ascii = {
  [[          ____                                         ]],
  [[         /___/\_                                       ]],
  [[        _\   \/_/\__                     __            ]],
  [[      __\       \/_/\            .--.--.|__|.--.--.--. ]],
  [[      \   __    __ \ \           |  |  ||  ||        | ]],
  [[     __\  \_\   \_\ \ \   __      \___/ |__||__|__|__| ]],
  [[    /_/\\   __   __  \ \_/_/\                          ]],
  [[    \_\/_\__\/\__\/\__\/_\_\/                          ]],
  [[       \_\/_/\       /_\_\/                            ]],
  [[          \_\/       \_\/                              ]]
}

-- g.startify_custom_header = 'startify#center(g:ascii)'
g.startify_custom_header = ascii
g.startify_relative_path = 1
g.startify_use_env = 1

g.startify_lists = {
  {type = "dir", header = {"Files: " .. fn.getcwd()}},
  {type = "sessions", header = {"Sessions"}},
  {type = "bookmarks", header = {"Bookmarks"}},
  {type = "commands", header = {"Commands"}}
}

g.startify_commands = {
  {up = {"Update Plugins", ":PlugUpdate"}},
  {ug = {"Upgrade Plugin Manager", ":PlugUpgrade"}},
  {ts = {"Update Treesitter", "TSUpdate"}},
  {ch = {"Check Health", "checkhealth"}}
}

g.startify_bookmarks = {
  {c = "~/.config/nvim/init.vim"},
  {g = "~/.gitconfig"},
  {z = "~/.zshrc"}
}
nmap("<leader>st", ":Startify<cr>")
