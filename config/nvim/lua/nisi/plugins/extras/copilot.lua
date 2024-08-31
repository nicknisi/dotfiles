return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    cond = not vim.g.vscode,
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          close = "<Esc>",
          next = "<C-J>",
          prev = "<C-K>",
          select = "<CR>",
          dismiss = "<C-X>",
        },
      },
      panel = {
        enabled = false,
      },
    },
  },
  {
    "zbirenbaum/copilot-cmp",
    cond = not vim.g.vscode,
    dependencies = {
      "hrsh7th/nvim-cmp",
    },
    config = true,
  },
}
