return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = false,
        keymap = {
          -- accept = "<Tab>",
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
    dependencies = {
      "hrsh7th/nvim-cmp",
    },
    config = true,
  },
}
