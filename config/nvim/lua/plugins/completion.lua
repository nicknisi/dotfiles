local colors = require("theme").colors

-- Set colors for completion items
vim.cmd("highlight! CmpItemAbbrMatch guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=" .. colors.lightblue)
vim.cmd("highlight! CmpItemKindFunction guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindMethod guibg=NONE guifg=" .. colors.magenta)
vim.cmd("highlight! CmpItemKindVariable guibg=NONE guifg=" .. colors.blue)
vim.cmd("highlight! CmpItemKindKeyword guibg=NONE guifg=" .. colors.fg)

return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "zbirenbaum/copilot-cmp",
      "onsails/lspkind-nvim",
      { "roobert/tailwindcss-colorizer-cmp.nvim", config = true },
    },
    config = function()
      local lspkind = require("lspkind")
      local cmp = require("cmp")
      local tailwind_formatter = require("tailwindcss-colorizer-cmp").formatter

      vim.o.completeopt = "menu,menuone,noselect"

      cmp.setup({
        ghost_text = { enabled = true },
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        mapping = {
          ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.close(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        },
        sources = cmp.config.sources({
          { name = "copilot" },
          { name = "vsnip" },
          { name = "nvim_lua" },
          { name = "nvim_lsp" },
          { name = "buffer", keyword_length = 5, max_item_count = 5 },
          { name = "path" },
        }),
        formatting = {
          fields = { cmp.ItemField.Menu, cmp.ItemField.Abbr, cmp.ItemField.Kind },
          format = lspkind.cmp_format({
            with_text = true,
            menu = {
              nvim_lsp = "ﲳ",
              nvim_lua = "",
              path = "ﱮ",
              buffer = "﬘",
              vsnip = "",
              -- treesitter = "",
              -- zsh = "",
              -- spell = "暈"
            },
            before = tailwind_formatter,
          }),
        },
        experimental = { native_menu = false, ghost_text = { enabled = true } },
      })
    end,
  },
}
