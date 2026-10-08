return {
  {
    "echasnovski/mini.nvim",
    version = "*",
    config = function()
      -- misc useful functions
      require("mini.misc").setup({})

      -- Better a/i text objects
      require("mini.ai").setup({})

      -- Surround with vim-surround keys so `s` stays substitute
      -- - ysiw) - add ) around word, yss) - around line, visual S) - around selection
      -- - ds' - delete ', cs)] - replace ) with ]
      require("mini.surround").setup({
        mappings = {
          add = "ys",
          delete = "ds",
          replace = "cs",
          find = "",
          find_left = "",
          highlight = "",
          update_n_lines = "",
          suffix_last = "",
          suffix_next = "",
        },
        search_method = "cover_or_next",
      })
      vim.keymap.del("x", "ys")
      vim.keymap.set(
        "x",
        "S",
        [[:<C-u>lua MiniSurround.add('visual')<CR>]],
        { silent = true, desc = "Surround selection" }
      )
      vim.keymap.set("n", "yss", "ys_", { remap = true, desc = "Surround line" })

      -- Splitjoin
      -- - gS - Split
      -- - gJ - Join
      require("mini.splitjoin").setup({
        mappings = {
          toggle = "",
          split = "gS",
          join = "gJ",
        },
      })

      -- only load tjese plugins if not in vscode
      if not vim.g.vscode then
        -- Better pairs
        require("mini.pairs").setup()
      end
    end,
  },
}
