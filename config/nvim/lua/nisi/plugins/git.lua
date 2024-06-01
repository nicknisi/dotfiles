return {
  {
    "tpope/vim-fugitive",
    lazy = false,
    keys = {
      { "<leader>gr", "<cmd>Gread<cr>", desc = "Read file from git" },
      { "<leader>gb", "<cmd>G blame<cr>", desc = "Read file from git" },
    },
    dependencies = { "tpope/vim-rhubarb" },
  },
  {
    "mhinz/vim-signify",
    -- init = function(_)
    --   vim.g.signify_skip = { vcs = { deny = { "git" } } }
    -- end,
    config = function(_, _)
      vim.api.nvim_set_hl(0, "SignifySignAdd", { link = "GitSignsAdd" })
      vim.api.nvim_set_hl(0, "SignifySignChange", { link = "GitSignsChange" })
      vim.api.nvim_set_hl(0, "SignifySignChangeDelete", { link = "GitSignsChange" })
      vim.api.nvim_set_hl(0, "SignifySignDelete", { link = "GitSignsDelete" })
      vim.api.nvim_set_hl(0, "SignifySignDeleteFirstLine", { link = "GitSignsDelete" })

      vim.g.signify_sign_add = "▎"
      vim.g.signify_sign_change = "▎"
      vim.g.signify_sign_delete = ""
      vim.g.signify_sign_delete_first_line = ""
      vim.g.signify_sign_change_delete = ""
    end,
  },
}
