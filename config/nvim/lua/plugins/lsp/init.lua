return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      -- Helpers to install LSPs and maintain them
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "nvimtools/none-ls.nvim",
      "jay-babu/mason-null-ls.nvim",
    },
    config = function()
      require("plugins.lsp.config").setup()
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = false,
      },
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettier", "prettierd" },
        javascriptreact = { "prettier", "prettierd" },
        typecript = { "prettier", "prettierd" },
        typecriptreact = { "prettier", "prettierd" },
        css = { "prettier", "prettierd" },
        html = { "prettier", "prettierd" },
        json = { "prettier", "prettierd" },
        jsonc = { "prettier", "prettierd" },
        yaml = { "prettier", "prettierd" },
        markdown = { "prettier", "prettierd" },
        graphql = { "prettier", "prettierd" },
      },
    },
  },
  {
    "folke/trouble.nvim",
    config = true,
    keys = {
      { "<leader>xx", "<cmd>TroubleToggle<cr>" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>" },
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>" },
    },
  },
}
