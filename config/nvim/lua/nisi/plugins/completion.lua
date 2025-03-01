local colors = require("nisi.colors")

-- Set colors for completion items
vim.cmd("highlight! CmpItemAbbrMatch guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemKindFunction guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindMethod guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindVariable guibg=NONE guifg=" .. colors.blue)
vim.cmd("highlight! CmpItemKindKeyword guibg=NONE guifg=" .. colors.fg)

return {
  {
    "saghen/blink.cmp",
    -- optional: provides snippets for the snippet source
    dependencies = {
      "rafamadriz/friendly-snippets",
    },

    event = "InsertEnter",

    version = "*",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "default",
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      },

      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = true },
        menu = {
          auto_show = function(ctx)
            return ctx.mode ~= "cmdline" or not vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
          end,
          draw = {
            treesitter = { "lsp" },
          },
        },
      },

      appearance = {
        -- Sets the fallback highlight groups to nvim-cmp's highlight groups
        -- Useful for when your theme doesn't support blink.cmp
        -- Will be removed in a future release
        use_nvim_cmp_as_default = false,
        -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = "mono",
      },

      cmdline = { enabled = false },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
    opts_extend = { "sources.default" },
  },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = {
  --     "hrsh7th/cmp-nvim-lsp",
  --     "hrsh7th/cmp-nvim-lua",
  --     "hrsh7th/cmp-buffer",
  --     "hrsh7th/cmp-path",
  --     "zbirenbaum/copilot-cmp",
  --     "onsails/lspkind-nvim",
  --     { "roobert/tailwindcss-colorizer-cmp.nvim", config = true },
  --   },
  --   cond = not vim.g.vscode,
  --   config = function()
  --     local lspkind = require("lspkind")
  --     local cmp = require("cmp")
  --     local tailwind_formatter = require("tailwindcss-colorizer-cmp").formatter
  --
  --     vim.opt.completeopt = { "menu", "menuone", "noselect" }
  --
  --     cmp.setup({
  --       ghost_text = { enabled = true },
  --       snippet = {
  --         expand = function(args)
  --           vim.fn["vsnip#anonymous"](args.body)
  --         end,
  --       },
  --       mapping = {
  --         ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
  --         ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
  --         ["<C-d>"] = cmp.mapping.scroll_docs(-4),
  --         ["<C-f>"] = cmp.mapping.scroll_docs(4),
  --         ["<C-Space>"] = cmp.mapping.complete(),
  --         ["<C-e>"] = cmp.mapping.close(),
  --         ["<CR>"] = cmp.mapping.confirm({ select = true }),
  --       },
  --       sources = cmp.config.sources({
  --         { name = "copilot" },
  --         { name = "vsnip" },
  --         { name = "nvim_lua" },
  --         { name = "nvim_lsp" },
  --         { name = "buffer", keyword_length = 5, max_item_count = 5 },
  --         { name = "path" },
  --       }),
  --       formatting = {
  --         fields = { cmp.ItemField.Menu, cmp.ItemField.Abbr, cmp.ItemField.Kind },
  --         format = lspkind.cmp_format({
  --           with_text = true,
  --           menu = {
  --             nvim_lsp = "ﲳ",
  --             nvim_lua = "",
  --             path = "ﱮ",
  --             buffer = "﬘",
  --             vsnip = "",
  --             -- treesitter = "",
  --             -- zsh = "",
  --             -- spell = "暈"
  --           },
  --           before = tailwind_formatter,
  --         }),
  --       },
  --       experimental = { native_menu = false, ghost_text = { enabled = true } },
  --     })
  --   end,
  -- },
}
