-- Completion highlights are now handled by the colorscheme
-- This allows proper light/dark mode adaptation

return {
  {
    "saghen/blink.cmp",
    -- optional: provides snippets for the snippet source
    dependencies = {
      "rafamadriz/friendly-snippets",
    },

    event = "InsertEnter",

    version = "1.*",

    ---@module 'blink.cmp'
    opts = {
      keymap = {
        preset = "none", -- Use 'none' to have full control
        ["<C-j>"] = { "select_next" },
        ["<C-k>"] = { "select_prev" },
        ["<CR>"] = { "accept", "fallback" }, -- Accept completion like Tab
        ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<Esc>"] = {
          function(cmp)
            if cmp.is_visible() then
              cmp.cancel()
            end
          end,
          "fallback",
        },
      },

      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        ghost_text = { enabled = false },
        menu = {
          auto_show = function(ctx)
            return ctx.mode ~= "cmdline" or not vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
          end,
          draw = {
            treesitter = { "lsp" },
          },
        },
      },

      cmdline = { enabled = false },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { "lsp", "snippets", "path", "buffer" },
      },
    },
    opts_extend = { "sources.default" },
  },
}
