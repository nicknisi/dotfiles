local telescope = require("telescope")
local actions = require("telescope.actions")
local nnoremap = require("utils").nnoremap

telescope.setup(
  {
    defaults = {
      mappings = {
        i = {
          ["<Esc>"] = actions.close, -- don't go into normal mode, just close
          ["<C-j>"] = actions.move_selection_next, -- scroll the list with <c-j>
          ["<C-k>"] = actions.move_selection_previous, -- scroll the list with <c-k>
          -- ["<C-\\->"] = actions.select_horizontal, -- open selection in new horizantal split
          -- ["<C-\\|>"] = actions.select_vertical, -- open selection in new vertical split
          ["<C-t>"] = actions.select_tab, -- open selection in new tab
          ["<C-y>"] = actions.preview_scrolling_up,
          ["<C-e>"] = actions.preview_scrolling_down
        }
      },
      vimgrepa_arguments = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filenames",
        "--line-number",
        "--column",
        "--smart-case",
        "--trim"
      }
    },
    pickers = {
      find_files = {
        find_command = {"fd", "--type", "f", "--strip-cwd-prefix"}
      }
    },
    extensions = {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "smart_case"
      }
    }
  }
)

telescope.load_extension("fzf")

-- mappings
nnoremap("<leader>ff", "<cmd>Telescope find_files<cr>")
nnoremap("<leader>fn", "<cmd>Telescope node_modules list<cr>")
nnoremap("<leader>fg", "<cmd>Telescope live_grep<cr>")
nnoremap("<leader>fb", "<cmd>Telescope buffers<cr>")
nnoremap("<leader>fh", "<cmd>Telescope help_tags<cr>")
