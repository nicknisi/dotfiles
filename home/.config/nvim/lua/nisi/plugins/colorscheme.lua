local utils = require("nisi.utils")
local config = require("nisi").config

return {
  -- Catppuccin theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = utils.is_dark_mode() and "mocha" or "latte", -- latte, frappe, macchiato, mocha
      -- dim_inactive = { enabled = config.transparent or false, shade = "dark", percentage = 0.6 },
      transparent_background = config.transparent or false, -- set to true to enable transparent background
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
      color_overrides = {
        macchiato = {
          -- True neutral dark base (no blue or brown tint)
          base = "#0B1215", -- Clean dark background
          mantle = "#1c1c1c", -- Darker
          crust = "#161616", -- Darkest

          -- Pure grayscale text colors
          text = "#d4d4d4",
          subtext1 = "#bbbbbb",
          subtext0 = "#a6a6a6",
          overlay2 = "#919191",
          overlay1 = "#7c7c7c",
          overlay0 = "#666666",
          surface2 = "#484848",
          surface1 = "#333333",
          surface0 = "#292929",

          -- Vibrant accent colors without blue dominance
          red = "#f7768e", -- Bright pink-red
          green = "#9ece6a", -- Fresh green
          yellow = "#e5c07b", -- Warm yellow
          blue = "#bb9af7", -- Replaced with purple
          mauve = "#d38aea", -- Bright purple
          teal = "#2dc7c4", -- True teal
          flamingo = "#f26d99", -- Bright orange
          lavender = "#d7a4f7", -- Light purple

          -- Additional colors if needed
          peach = "#ff8800",
          maroon = "#ff6188",
          sky = "#95e6cb", -- Mint instead of sky blue
          sapphire = "#c07ab8", -- Purple-pink instead of sapphire
          rosewater = "#ffa0a0",
        },
        latte = {
          -- Clean light base colors
          base = "#f8f8f8", -- Clean light background
          mantle = "#f0f0f0", -- Slightly darker
          crust = "#e8e8e8", -- Subtle border color

          -- Refined grayscale text colors for light mode
          text = "#2c2c2c",
          subtext1 = "#4a4a4a",
          subtext0 = "#666666",
          overlay2 = "#7c7c7c",
          overlay1 = "#919191",
          overlay0 = "#a6a6a6",
          surface2 = "#c8c8c8",
          surface1 = "#d4d4d4",
          surface0 = "#e0e0e0",

          -- Vibrant but readable accent colors for light mode
          red = "#d73a49", -- GitHub-like red
          green = "#28a745", -- Clear green
          yellow = "#ffd33d", -- Bright yellow
          blue = "#7c3aed", -- Deep purple (matching dark mode preference)
          mauve = "#8b5cf6", -- Bright purple
          teal = "#20b2aa", -- True teal
          flamingo = "#f56565", -- Coral-like orange
          lavender = "#a78bfa", -- Light purple

          -- Additional colors adapted for light mode
          peach = "#ff8c00",
          maroon = "#dc2626",
          sky = "#06b6d4", -- Bright cyan
          sapphire = "#8b5cf6", -- Purple consistent with blue
          rosewater = "#f43f5e",
        },
      },
      integrations = {
        treesitter = true,
        blink_cmp = true,
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
        telescope = {
          enabled = true,
          style = "nvchad",
        },
        treesitter_context = true,
        which_key = true,
        ts_rainbow = true,
      },
      custom_highlights = function(colors)
        return {
          NormalFloat = { bg = colors.mantle },
          FloatBorder = { bg = colors.mantle, fg = colors.overlay0 },
          TelescopeNormal = { bg = colors.mantle },
          TelescopeBorder = { bg = colors.mantle, fg = colors.overlay0 },
          NoiceCmdlinePopup = { bg = colors.mantle },
          NoicePopup = { bg = colors.mantle },
          WhichKeyFloat = { bg = colors.mantle },
          -- Add Telescope prompt specific highlights
          TelescopePrompt = { bg = colors.crust },
          TelescopePromptNormal = { bg = colors.crust },
          TelescopePromptBorder = { bg = colors.crust, fg = colors.overlay0 },
          TelescopePromptPrefix = { bg = colors.crust, fg = colors.blue },
          TelescopePromptTitle = { bg = colors.crust, fg = colors.blue },

          -- Different colors for results and preview
          TelescopeResults = { bg = colors.mantle },
          TelescopePreview = { bg = colors.mantle },
          TelescopeResultsTitle = { bg = colors.mantle, fg = colors.blue },
          TelescopePreviewTitle = { bg = colors.mantle, fg = colors.blue },

          -- Selection highlights
          TelescopeSelection = { bg = colors.surface0, fg = colors.text },
          TelescopeSelectionCaret = { bg = colors.surface0, fg = colors.blue },
        }
      end,
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = config.transparent or false,
      styles = {
        comments = { italic = true },
      },
    },
  },
}
