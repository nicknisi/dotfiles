return {
  {
    "nvim-telescope/telescope.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim", -- Power telescope with FZF
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-rg.nvim",
      "nvim-telescope/telescope-node-modules.nvim",
    },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<Esc>"] = require("telescope.actions").close, -- don't go into normal mode, just close
              ["<C-j>"] = require("telescope.actions").move_selection_next, -- scroll the list with <c-j>
              ["<C-k>"] = require("telescope.actions").move_selection_previous, -- scroll the list with <c-k>
              -- ["<C-\\->"] = actions.select_horizontal, -- open selection in new horizantal split
              -- ["<C-\\|>"] = actions.select_vertical, -- open selection in new vertical split
              ["<C-t>"] = require("telescope.actions").select_tab, -- open selection in new tab
              ["<C-y>"] = require("telescope.actions").preview_scrolling_up,
              ["<C-e>"] = require("telescope.actions").preview_scrolling_down,
            },
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--trim",
          },
          prompt_prefix = "   ",
          selection_caret = "  ",
          entry_prefix = "  ",
          initial_mode = "insert",
          selection_strategy = "reset",
          sorting_strategy = "ascending",
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = { prompt_position = "top", preview_width = 0.55, results_width = 0.8 },
            vertical = { mirror = false },
            width = 0.87,
            height = 0.80,
            preview_cutoff = 120,
          },
          file_sorter = require("telescope.sorters").get_fuzzy_file,
          file_ignore_patterns = { "node_modules" },
          generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
          path_display = { "truncate" },
          winblend = 0,
          border = {},
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          color_devicons = true,
          use_less = true,
          set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
          file_previewer = require("telescope.previewers").vim_buffer_cat.new,
          grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
          qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
          -- Developer configurations: Not meant for general override
          buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
        },
        pickers = { find_files = { find_command = { "fd", "--type", "f", "--hidden", "--strip-cwd-prefix" } } },
        extensions = {
          fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true, case_mode = "smart_case" },
        },
      })

      local nnoremap = require("utils").nnoremap
      nnoremap("<leader>ff", "<cmd>Telescope find_files<cr>")
      nnoremap("<leader>fs", "<cmd>Telescope git_files<cr>")
      nnoremap("<leader>fo", "<cmd>Telescope oldfiles<cr>")
      nnoremap("<leader>fn", "<cmd>Telescope node_modules list<cr>")
      nnoremap("<leader>fg", "<cmd>Telescope live_grep<cr>")
      nnoremap("<leader>fr", "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<cr>")
      nnoremap("<leader>fb", "<cmd>Telescope buffers<cr>")
      nnoremap("<leader>r", "<cmd>Telescope buffers<cr>")
      nnoremap("<leader>fh", "<cmd>Telescope help_tags<cr>")
      if vim.fn.isdirectory(".git") then
        nnoremap("<leader>t", "<cmd>Telescope git_files<cr>")
        nnoremap("<D-p>", "<cmd>Telescope git_files<cr>")
      else
        nnoremap("<leader>t", "<cmd>Telescope find_files<cr>")
        nnoremap("<D-p>", "<cmd>Telescope find_files<cr>")
      end
    end,
  },
}
