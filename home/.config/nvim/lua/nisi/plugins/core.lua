return {
  "tpope/vim-unimpaired",
  "tpope/vim-ragtag",
  "tpope/vim-abolish",
  "tpope/vim-repeat",
  "tpope/vim-sleuth",
  "editorconfig/editorconfig-vim", -- TODO is this still required?
  {
    "andymass/vim-matchup",
    cond = not vim.g.vscode,
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
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
      { "<leader>sr", "<cmd>lua require('spectre').open()<cr>", desc = "Open spectre" },
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
      -- User defined loops
      additions = {
        -- { "Foo", "Bar" },
        -- { "tic", "tac", "toe" },
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
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
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
