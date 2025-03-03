return {
  -- Python syntax and indent
  {
    "vim-python/python-syntax",
    ft = { "python" },
    init = function()
      vim.g.python_highlight_all = 1
    end,
  },

  -- Python indentation
  {
    "Vimjas/vim-python-pep8-indent",
    ft = { "python" },
  },

  -- Python virtual environment support
  {
    "AckslD/swenv.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "python" },
    opts = {},
    keys = {
      {
        "<leader>pe",
        function()
          require("swenv.api").pick_venv()
        end,
        desc = "Pick virtual environment",
      },
      {
        "<leader>pc",
        function()
          require("swenv.api").get_current_venv()
        end,
        desc = "Show current virtual environment",
      },
    },
  },

  -- Python debugging
  {
    "mfussenegger/nvim-dap-python",
    ft = { "python" },
    dependencies = {
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
    },
    config = function()
      local path = require("mason-registry").get_package("debugpy"):get_install_path()
      require("dap-python").setup(path .. "/venv/bin/python")

      -- Set up keymaps
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          local buffer = vim.api.nvim_get_current_buf()
          vim.keymap.set("n", "<leader>dt", function()
            require("dap-python").test_method()
          end, { buffer = buffer, desc = "Debug Test Method" })
          vim.keymap.set("n", "<leader>dc", function()
            require("dap-python").test_class()
          end, { buffer = buffer, desc = "Debug Test Class" })
          vim.keymap.set("n", "<leader>ds", function()
            require("dap-python").debug_selection()
          end, { buffer = buffer, desc = "Debug Selection" })
        end,
      })
    end,
  },

  -- Python REPL
  {
    "michaelb/sniprun",
    build = "bash ./install.sh",
    config = function()
      require("sniprun").setup({
        display = { "TempFloatingWindow" },
        interpreter_options = {
          Python3_original = {
            interpreter = "python",
          },
        },
      })
    end,
    keys = {
      {
        "<leader>sr",
        function()
          require("sniprun").run()
        end,
        desc = "Run code snippet",
        mode = { "n", "v" },
      },
      {
        "<leader>sc",
        function()
          require("sniprun").clear()
        end,
        desc = "Clear SnipRun",
      },
    },
  },
}
