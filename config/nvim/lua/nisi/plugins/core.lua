return {
  "tpope/vim-unimpaired",
  "tpope/vim-ragtag",
  "tpope/vim-abolish",
  "tpope/vim-repeat",
  "tpope/vim-sleuth",
  {
    "andymass/vim-matchup",
    cond = not vim.g.vscode,
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
      -- disable treesitter integration until vim-matchup supports nvim 0.12
      -- (0.12 changed metadata.range → metadata.offset in treesitter directives)
      vim.g.matchup_treesitter_enabled = false
    end,
  },
  {
    "itchyny/vim-qfedit",
    cond = not vim.g.vscode,
    event = "VeryLazy",
  },
  {
    "nvim-pack/nvim-spectre",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cond = not vim.g.vscode,
    config = true,
    keys = {
      { "<leader>sw", "<cmd>lua require('spectre').open_visual({select_word=true})<cr>", desc = "Open spectre" },
      { "<leader>sp", "<cmd>lua require('spectre').open_file_search()<cr>", desc = "Open spectre" },
      { "<leader>ss", "<cmd>lua require('spectre').open()<cr>", desc = "Open spectre" },
    },
  },
  {
    "nat-418/boole.nvim",
    opts = {
      mappings = {
        increment = "<C-a>",
        decrement = "<C-x>",
      },
      allow_caps_additions = {
        { "enable", "disable" },
        -- enable → disable
        -- Enable → Disable
        -- ENABLE → DISABLE
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    cond = not vim.g.vscode,
    opts = {},
  },
  {
    "Bekaboo/dropbar.nvim",
    -- optional, but required for fuzzy finder support
    cond = not vim.g.vscode,
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
    },
  },
}
