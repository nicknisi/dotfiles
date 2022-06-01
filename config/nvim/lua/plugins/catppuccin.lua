local catppuccin = require("catppuccin")
local ctp_feline = require("catppuccin.groups.integrations.feline")
local feline = require("feline")

catppuccin.setup {
  dim_inactive = {
    enabled = false,
    shade = "dark",
    percentage = 0.15
  },
  transparent_background = false,
  term_colors = false,
  compile = {
    enabled = false,
    path = vim.fn.stdpath "cache" .. "/catppuccin",
    suffix = "_compiled"
  },
  styles = {
    comments = {"italic"},
    conditionals = {"italic"},
    loops = {},
    functions = {"bold"},
    keywords = {},
    strings = {},
    variables = {},
    numbers = {},
    booleans = {},
    properties = {},
    types = {},
    operators = {}
  },
  integrations = {
    treesitter = true,
    native_lsp = {
      enabled = true,
      virtual_text = {
        errors = {"italic"},
        hints = {"italic"},
        warnings = {"italic"},
        information = {"italic"}
      },
      underlines = {
        errors = {"underline"},
        hints = {"underline"},
        warnings = {"underline"},
        information = {"underline"}
      }
    },
    lsp_trouble = false,
    cmp = true,
    gitsigns = true,
    telescope = true,
    nvimtree = {
      enabled = true,
      show_root = true,
      transparent_panel = false
    },
    markdown = true,
    ts_rainbow = false
  }
}

ctp_feline.setup {}
feline.setup(
  {
    components = ctp_feline.get()
  }
)
