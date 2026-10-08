local icons = require("nisi.assets").icons

return {
  {
    -- Edit the filesystem in a buffer
    "stevearc/oil.nvim",
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
    },
    cond = not vim.g.vscode,
    opts = {},
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    -- File explorer plugin
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = true,
    cond = not vim.g.vscode,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      {
        "s1n7ax/nvim-window-picker",
        config = function()
          require("window-picker").setup({
            autoselect_one = true,
            include_current = false,
            filter_rules = {
              bo = {
                filetype = { "neo-tree", "neo-tree-popup", "notify" },
                buftype = { "terminal", "quickfix" },
              },
            },
            border = { style = "rounded", highlight = "Normal" },
            other_win_hl_color = "#e35e4f",
          })
        end,
      },
    },
    keys = {
      { "<leader>k", "<cmd>Neotree toggle reveal<cr>", desc = "Toggle file drawer" },
    },
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      use_default_mappings = false,
      source_selector = { winbar = true, statusline = false },
      default_component_configs = {
        container = { enable_character_fade = true },
        indent = {
          indent_size = 2,
          padding = 1, -- extra padding on left hand side
          with_markers = true,
          indent_marker = "│",
          last_indent_marker = "└",
          highlight = "NeoTreeIndentMarker",
          expander_collapsed = icons.arrow_closed,
          expander_expanded = icons.arrow_open,
          expander_highlight = "NeoTreeExpander",
        },
        icon = {
          folder_closed = icons.default,
          folder_open = icons.open,
          folder_empty = icons.empty,
          default = "*",
          highlight = "NeoTreeFileIcon",
        },
        modified = { symbol = "[+]", highlight = "NeoTreeModified" },
        name = { trailing_slash = false, use_git_status_colors = true, highlight = "NeoTreeFileName" },
        git_status = {
          symbols = {
            added = icons.added,
            modified = "",
            deleted = icons.deleted,
            renamed = icons.renamed,
            untracked = icons.untracked,
            ignored = icons.ignored,
            unstaged = icons.unstaged,
            staged = icons.staged,
            conflict = icons.conflict,
          },
        },
      },
      window = {
        position = "right",
        width = 40,
        mapping_options = { noremap = true, nowait = true },
        mappings = {
          ["<space>"] = {
            "toggle_node",
            nowait = false, -- disable `nowait` if you have existing combos starting with this char that you want to use
          },
          ["<2-LeftMouse>"] = "open",
          ["<cr>"] = "open",
          ["<esc>"] = "revert_preview",
          ["P"] = { "toggle_preview", config = { use_float = true } },
          ["l"] = "focus_preview",
          ["S"] = "open_split",
          ["s"] = "open_vsplit",
          ["t"] = "open_tabnew",
          ["w"] = "open_with_window_picker",
          ["C"] = "close_node",
          ["z"] = "close_all_nodes",
          ["a"] = {
            "add",
            config = {
              show_path = "none", -- "none", "relative", "absolute"
            },
          },
          ["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
          ["d"] = "delete",
          ["r"] = "rename",
          ["y"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
          ["m"] = "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
          ["q"] = "close_window",
          ["R"] = "refresh",
          ["?"] = "show_help",
          ["<"] = "prev_source",
          [">"] = "next_source",
        },
      },
      nesting_rules = {
        ["ts"] = { "spec.ts", "spec.tsx", "stories.tsx", "stories.mdx" },
        ["tsx"] = { "spec.ts", "spec.tsx", "stories.tsx", "stories.mdx" },
        ["js"] = { "d.ts" },
        ["jsx"] = { "d.ts" },
      },
      filesystem = {
        filtered_items = {
          visible = true, -- when true, they will just be displayed differently than normal items
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_hidden = true, -- only works on Windows for hidden files/directories
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            ".DS_Store",
            "thumbs.db",
          },
        },
        bind_to_cwd = true,
        cwd_target = { sidebar = "tab", current = "window" },
        follow_current_file = { enabled = true }, -- This will find and focus the file in the active buffer every
        group_empty_dirs = false, -- when true, empty folders will be grouped together
        hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
        window = {
          mappings = {
            ["<bs>"] = "navigate_up",
            ["H"] = "toggle_hidden",
            ["/"] = "fuzzy_finder",
            ["D"] = "fuzzy_finder_directory",
            ["f"] = "filter_on_submit",
            ["<c-x>"] = "clear_filter",
            ["[g"] = "prev_git_modified",
            ["]g"] = "next_git_modified",
          },
        },
      },
      buffers = {
        follow_current_file = { enabled = true }, -- This will find and focus the file in the active buffer every
        group_empty_dirs = true, -- when true, empty folders will be grouped together
        show_unloaded = true,
        window = {
          mappings = {
            ["bd"] = "buffer_delete",
            ["<bs>"] = "navigate_up",
          },
        },
      },
      git_status = {
        window = {
          position = "float",
          mappings = {
            ["A"] = "git_add_all",
            ["gu"] = "git_unstage_file",
            ["ga"] = "git_add_file",
            ["gr"] = "git_revert_file",
            ["gc"] = "git_commit",
            ["gp"] = "git_push",
            ["gg"] = "git_commit_and_push",
          },
        },
      },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    lazy = false,
    cond = not vim.g.vscode,
    dependencies = {
      "nvim-lua/plenary.nvim", -- Power telescope with FZF
      "nvim-telescope/telescope-rg.nvim",
      "nvim-telescope/telescope-node-modules.nvim",
    },
    keys = function()
      local keys = {
        { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
        { "<leader>fo", "<cmd>Telescope oldfiles<cr>", desc = "Find MRU files" },
        { "<leader>fn", "<cmd>Telescope node_modules list<cr>", desc = "List node_modules" },
        { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Find using live grep" },
        {
          "<leader>fr",
          "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<cr>",
          desc = "Find sing live raw grep",
        },
        { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find in buffers" },
        { "<leader>r", "<cmd>Telescope buffers<cr>", desc = "Find in buffers" },
        { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Find in help" },
      }
      if vim.fs.root(vim.fn.getcwd(), ".git") then
        vim.list_extend(keys, {
          { "<leader>fs", "<cmd>Telescope git_files<cr>", desc = "Find Git files" },
          {
            "<leader>t",
            function()
              require("telescope.builtin").find_files({
                find_command = { "rg", "--files", "--hidden", "--glob", "!.git" },
              })
            end,
            desc = "Find files (respects .gitignore)",
          },
          { "<D-p>", "<cmd>Telescope git_files<cr>", desc = "Find in Git files" },
          { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Commits" },
          { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Status" },
        })
      else
        vim.list_extend(keys, {
          { "<leader>t", "<cmd>Telescope find_files<cr>", desc = "Find in files" },
          { "<D-p>", "<cmd>Telescope find_files<cr>", desc = "Find in files" },
        })
      end

      return keys
    end,
    opts = function()
      local actions = require("telescope.actions")

      return {
        defaults = {
          mappings = {
            i = {
              ["<Esc>"] = actions.close, -- don't go into normal mode, just close
              ["<C-j>"] = actions.move_selection_next, -- scroll the list with <c-j>
              ["<C-k>"] = actions.move_selection_previous, -- scroll the list with <c-k>
              ["<C-t>"] = actions.select_tab, -- open selection in new tab
              ["<C-y>"] = actions.preview_scrolling_up,
              ["<C-e>"] = actions.preview_scrolling_down,
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
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = { prompt_position = "top", preview_width = 0.55, results_width = 0.8 },
            vertical = { mirror = false },
            width = 0.87,
            height = 0.80,
            preview_cutoff = 120,
          },
          file_ignore_patterns = { "node_modules" },
          path_display = { "truncate" },
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        },
        pickers = { find_files = { find_command = { "fd", "--type", "f", "--hidden", "--strip-cwd-prefix" } } },
      }
    end,
  },
}
