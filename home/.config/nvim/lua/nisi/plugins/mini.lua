return {
  {
    "echasnovski/mini.nvim",
    version = "*",
    config = function()
      -- misc useful functions
      require("mini.misc").setup({})

      -- Better a/i text objects
      require("mini.ai").setup({})

      -- Better surround
      -- - saiw) - [S]urround [A]dd [I]n [W]ord with )
      -- - sd' - [S]urround [D]elete '
      -- - sr)'' - [S]urround [R]eplace ) with (
      require("mini.surround").setup({})

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

      -- Highlight word under cursor
      require("mini.cursorword").setup({})

      -- Move text in any direction
      require("mini.move").setup({
        mappings = {
          left = "<M-S-h>",
          right = "<M-S-l>",
          down = "<M-S-j>",

          up = "<M-S-k>",
          -- Move current line in Normal mode
          line_left = "<M-S-h>",
          line_right = "<M-S-l>",
          line_down = "<M-S-j>",
          line_up = "<M-S-k>",
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
