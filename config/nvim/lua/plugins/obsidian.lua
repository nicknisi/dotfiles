return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-lua/popup.nvim",
    "nvim-telescope/telescope.nvim",
    "hrsh7th/nvim-cmp",
    "nvim-treesitter/nvim-treesitter",
    "epwalsh/pomo.nvim"
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/vaults/Obsidian/"
      }
    },
  }
}
