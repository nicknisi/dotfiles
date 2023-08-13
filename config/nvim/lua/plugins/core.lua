return {
  "tpope/vim-commentary",
  "tpope/vim-unimpaired",
  "tpope/vim-surround",
  "tpope/vim-ragtag",
  "tpope/vim-abolish",
  "tpope/vim-repeat",
  "AndrewRadev/splitjoin.vim",
  "tpope/vim-sleuth",
  "editorconfig/editorconfig-vim", -- TODO is this still required?
  {
    "tpope/vim-fugitive",
    lazy = false,
    keys = {
      { "<leader>gr", "<cmd>Gread<cr>", desc = "read file from git" },
      { "<leader>gb", "<cmd>G blame<cr>", desc = "read file from git" },
    },
    dependencies = { "tpope/vim-rhubarb" },
  },
  { "itchyny/vim-qfedit", event = "VeryLazy" },
  -- { "dmmulroy/tsc.nvim", config = true },
  {
    "hrsh7th/vim-vsnip",
    dependencies = {
      "hrsh7th/cmp-vsnip",
      "hrsh7th/vim-vsnip-integ",
    },
    config = function()
      local snippet_dir = os.getenv("DOTFILES") .. "/config/nvim/snippets"
      vim.g.vsnip_snippet_dir = snippet_dir
      vim.g.vsnip_filetypes = {
        javascriptreact = { "javascript" },
        typescriptreact = { "typescript" },
        ["typescript.tsx"] = { "typescript" },
      }
    end,
  },
  { "windwp/nvim-autopairs", config = true },
  { "alvarosevilla95/luatab.nvim", config = true },
  { "MunifTanjim/nui.nvim", lazy = true },

  -- improve the default neovim interfaces, such as refactoring
  { "stevearc/dressing.nvim", event = "VeryLazy" },

  -- tools for helping with neovim development
  { "folke/neodev.nvim", config = true },
}
