local utils = require("nisi.utils")
return {
  -- Catppuccin theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      dim_inactive = { enabled = false, shade = "dark", percentage = 0.15 },
      transparent_background = true,
      term_colors = true,
      compile = { enabled = true, path = vim.fn.stdpath("cache") .. "/catppuccin", suffix = "_compiled" },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = { "bold" },
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      integrations = {
        treesitter = true,
        cmp = true,
        gitsigns = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
        neotree = true,
        noice = true,
        notify = true,
        telescope = true,
        treesitter_context = true,
        which_key = true,
        ts_rainbow = true,
      },
    },
  },
}
