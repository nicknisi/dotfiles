-- don't show listchars in startup
vim.cmd [[
augroup startup
  autocmd!
  autocmd FileType startup setlocal list&
augroup end
]]

local startup = require("startup")
local header = {
  [[       ____                                         ]],
  [[      /___/\_                                       ]],
  [[     _\   \/_/\__                     __            ]],
  [[   __\       \/_/\            .--.--.|__|.--.--.--. ]],
  [[   \   __    __ \ \           |  |  ||  ||        | ]],
  [[  __\  \_\   \_\ \ \   __      \___/ |__||__|__|__| ]],
  [[ /_/\\   __   __  \ \_/_/\                          ]],
  [[ \_\/_\__\/\__\/\__\/_\_\/                          ]],
  [[    \_\/_/\       /_\_\/                            ]],
  [[       \_\/       \_\/                              ]]
}

startup.setup(
  {
    header = {
      type = "text",
      align = "center",
      fold_section = false,
      title = "Header",
      content = header,
      highlight = "Statement"
    },
    body = {
      type = "mapping",
      align = "center",
      fold_section = false,
      title = "Basic Commands",
      margin = 5,
      content = {
        {" Find File", "Telescope find_files", "<leader>ff"},
        {" Find File (FZF)", "GitFiles", "<leader>t"},
        {" Find Word", "Telescope live_grep", "<leader>fg"},
        {" Recent Files", "Telescope oldfiles", "<leader>fo"},
        {" Open File Drawer", "lua NvimTreeConfig.find_toggle()", "<leader>k"},
        {" Open Git Index", ":Ge:", ":Ge:"}
      },
      highlight = "String"
    },
    footer = {
      type = "text",
      align = "center",
      fold_section = false,
      title = "Footer",
      margin = 5,
      content = {"https://github.com/nicknisi/dotfiles"},
      highlight = "Number",
      default_color = ""
    },
    colors = {
      background = "#1f2227",
      folded_section = "#56b6c2"
    },
    mappings = {
      execute_command = "<CR>",
      open_file = "o",
      open_file_split = "<c-o>",
      open_section = "<TAB>",
      open_help = "?",
      quit = "q"
    },
    options = {
      disable_statuslines = true,
      after = function()
        require("startup.utils").oldfiles_mappings()
      end
    },
    parts = {
      "header",
      "body",
      "footer"
    }
  }
)
