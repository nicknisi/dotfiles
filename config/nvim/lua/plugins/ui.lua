local theme = require("theme")
local icons = theme.icons

local is_dark = require("utils").is_dark_mode()

return {
  -- fast colorizer for showing hex colors
  {
    "NvChad/nvim-colorizer.lua",
    opts = {
      filetypes = { "*" },
      user_default_options = {
        mode = "background",
        tailwind = true,
        RGB = true,
        RRGGBB = true,
        names = true,
        RRGGBBAA = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
      },
    },
  },

  -- file drawer plugin
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      {
        "s1n7ax/nvim-window-picker",
        -- tag = "v1.*",
        config = function()
          require("window-picker").setup({
            autoselect_one = true,
            include_current = false,
            filter_rules = {
              bo = {
                filetype = { "nep-tree", "neo-tree-popup", "notify" },
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
      { "<leader>k", "<cmd>Neotree toggle reveal<cr>" },
    },
    opts = {
      -- don't reset the cursor position when opening a file
      disable_netrw = true,
      hijack_netrw = true,
      close_if_last_window = false, -- Close Neo-tree if it is the last window left in the tab popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      sort_case_insensitive = false, -- used when sorting files and directories in the tree
      use_default_mappings = false,
      sort_function = nil, -- use a custom function for sorting files and directories in the tree
      source_selector = { winbar = true, statusline = false },
      default_component_configs = {
        container = { enable_character_fade = true },
        indent = {
          indent_size = 2,
          padding = 1, -- extra padding on left hand side
          -- indent guides
          with_markers = true,
          indent_marker = "│",
          last_indent_marker = "└",
          highlight = "NeoTreeIndentMarker",
          -- expander config, needed for nesting files
          with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
          expander_collapsed = icons.arrow_closed,
          expander_expanded = icons.arrow_open,
          expander_highlight = "NeoTreeExpander",
        },
        icon = {
          folder_closed = icons.default,
          folder_open = icons.default_open,
          folder_empty = icons.empty_open,
          -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
          -- then these will never be used.
          default = "*",
          highlight = "NeoTreeFileIcon",
        },
        modified = { symbol = "[+]", highlight = "NeoTreeModified" },
        name = { trailing_slash = false, use_git_status_colors = true, highlight = "NeoTreeFileName" },
        git_status = {
          symbols = {
            -- Change type
            added = icons.added,
            modified = "",
            deleted = icons.deleted,
            renamed = icons.renamed,
            -- Status type
            untracked = icons.untracked,
            ignored = icons.ignored,
            unstaged = icons.unstaged,
            staged = icons.staged,
            conflict = icons.conflict,
          },
        },
      },
      window = {
        position = "left",
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
          -- ["S"] = "split_with_window_picker",
          -- ["s"] = "vsplit_with_window_picker",
          ["t"] = "open_tabnew",
          -- ["<cr>"] = "open_drop",
          -- ["t"] = "open_tab_drop",
          ["w"] = "open_with_window_picker",
          -- ["P"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
          ["C"] = "close_node",
          ["z"] = "close_all_nodes",
          -- ["Z"] = "expand_all_nodes",
          ["a"] = {
            "add",
            -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
            -- some commands may take optional config options, see `:h neo-tree-mappings` for details
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
          -- ["c"] = {
          --  "copy",
          --  config = {
          --    show_path = "none" -- "none", "relative", "absolute"
          --  }
          -- }
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
          hide_by_name = {
            -- "node_modules"
          },
          hide_by_pattern = { -- uses glob style patterns
            -- "*.meta",
            -- "*/src/*/tsconfig.json",
          },
          always_show = { -- remains visible even if other settings would normally hide it
            -- ".gitignored",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            ".DS_Store",
            "thumbs.db",
          },
          never_show_by_pattern = { -- uses glob style patterns
            -- ".null-ls_*",
          },
        },
        bind_to_cwd = true,
        cwd_target = { sidebar = "tab", current = "window" },
        follow_current_file = true, -- This will find and focus the file in the active buffer every
        -- time the current file is changed while the tree is open.
        group_empty_dirs = false, -- when true, empty folders will be grouped together
        hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
        -- in whatever position is specified in window.position
        -- "open_current",  -- netrw disabled, opening a directory opens within the
        -- window like netrw would, regardless of window.position
        -- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
        use_libuv_file_watcher = false, -- This will use the OS level file watchers to detect changes
        -- instead of relying on nvim autocmd events.
        window = {
          mappings = {
            ["<bs>"] = "navigate_up",
            -- ["<c-.>"] = "set_root",
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
        follow_current_file = true, -- This will find and focus the file in the active buffer every
        -- time the current file is changed while the tree is open.
        group_empty_dirs = true, -- when true, empty folders will be grouped together
        show_unloaded = true,
        window = {
          mappings = {
            ["bd"] = "buffer_delete",
            ["<bs>"] = "navigate_up",
            -- ["<c-.>"] = "set_root",
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

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        icons_enabled = true,
        theme = "auto",
        section_separators = { right = "", left = "" },
        component_separators = "", --{ right = "", left = "" },
      },
      sections = {
        lualine_a = {
          { "mode" },
          {
            "macro-recording",
            fmt = function()
              local recording_register = vim.fn.reg_recording()
              if recording_register == "" then
                return ""
              else
                return "Recording @" .. recording_register
              end
            end,
          },
        },
        lualine_b = {
          "branch",
          { "diff", symbols = { added = " ", modified = " ", removed = "󰮉 " } },
          "diagnostics",
        },
        lualine_c = { "filename", "searchcount" },
        lualine_x = { "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
    config = function(_, opts)
      local lualine = require("lualine")
      lualine.setup(opts)
      vim.api.nvim_create_autocmd("RecordingEnter", {
        callback = function()
          -- refresh lualine when entering record mode
          lualine.refresh({ place = { "lualine_a" } })
        end,
      })
    end,
  },

  -- Floating statuslines. This is used to shwo buffer names in splits
  { "b0o/incline.nvim", opts = { hide = { cursorline = false, focused_win = false, only_win = true } } },

  -- Show git diff in sign column
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { hl = "GitSignsAdd", text = "┃", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
        change = { hl = "GitSignsChange", text = "┃", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
        delete = { hl = "GitSignsDelete", text = "_", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
        topdelete = { hl = "GitSignsDelete", text = "‾", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
        changedelete = { hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
      },
      numhl = false,
      linehl = false,
      -- keymaps = {
      --   -- Default keymap options
      --   noremap = true,
      --   ["n ]c"] = { expr = true, "&diff ? ']c' : '<cmd>lua require\"gitsigns.actions\".next_hunk()<CR>'" },
      --   ["n [c"] = { expr = true, "&diff ? '[c' : '<cmd>lua require\"gitsigns.actions\".prev_hunk()<CR>'" },
      --   ["n <leader>hs"] = '<cmd>lua require"gitsigns".stage_hunk()<CR>',
      --   ["v <leader>hs"] = '<cmd>lua require"gitsigns".stage_hunk({vim.fn.line("."), vim.fn.line("v")})<CR>',
      --   ["n <leader>hu"] = '<cmd>lua require"gitsigns".undo_stage_hunk()<CR>',
      --   ["n <leader>hr"] = '<cmd>lua require"gitsigns".reset_hunk()<CR>',
      --   ["v <leader>hr"] = '<cmd>lua require"gitsigns".reset_hunk({vim.fn.line("."), vim.fn.line("v")})<CR>',
      --   ["n <leader>hR"] = '<cmd>lua require"gitsigns".reset_buffer()<CR>',
      --   ["n <leader>hp"] = '<cmd>lua require"gitsigns".preview_hunk()<CR>',
      --   ["n <leader>hb"] = '<cmd>lua require"gitsigns".blame_line(true)<CR>',
      --   -- Text objects
      --   ["o ih"] = ':<C-U>lua require"gitsigns.actions".select_hunk()<CR>',
      --   ["x ih"] = ':<C-U>lua require"gitsigns.actions".select_hunk()<CR>',
      -- },
      watch_gitdir = { interval = 1000, follow_files = true },
      current_line_blame_opts = { delay = 1000, virtual_text_pos = "eol" },
      current_line_blame = false,
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil, -- Use default
      word_diff = false,
      diff_opts = { internal = true },
    },
  },

  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      style = is_dark and "storm" or "day", -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
      light_style = "day", -- The theme is used when the background is set to light
      transparent = true, -- Enable this to disable setting the background color
      terminal_colors = true, -- Configure the colors used when opening a `:terminal` in [Neovim](https://github.com/neovim/neovim)
      styles = {
        -- Style to be applied to different syntax groups
        -- Value is any valid attr-list value for `:help nvim_set_hl`
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        -- Background styles. Can be "dark", "transparent" or "normal"
        sidebars = "dark", -- style for sidebars, see below
        floats = "dark", -- style for floating windows
      },
      sidebars = { "qf", "help" }, -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
      day_brightness = 0.3, -- Adjusts the brightness of the colors of the **Day** style. Number between 0 and 1, from dull to vibrant colors
      hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
      dim_inactive = false, -- dims inactive windows
      lualine_bold = false, -- When `true`, section headers in the lualine theme will be bold
    },
  },

  -- everforest theme
  {
    "neanias/everforest-nvim",
    version = false,
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    -- Optional; default configuration will be used if setup isn't called.
    config = function()
      require("everforest").setup({
        transparent_background_level = 2,
      })
    end,
  },

  -- Catppuccin theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = require("utils").is_dark_mode() and "mocha" or "latte",
      dim_inactive = { enabled = false, shade = "dark", percentage = 0.15 },
      transparent_background = true,
      term_colors = true,
      compile = { enabled = true, path = vim.fn.stdpath("cache") .. "/catppuccin", suffix = "_compiled" },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = { "bold" },
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
        lsp_trouble = false,
        cmp = true,
        gitsigns = true,
        telescope = true,
        markdown = true,
        ts_rainbow = true,
      },
    },
  },

  -- Prettier notifications
  {
    "rcarriga/nvim-notify",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss({ silent = true, pending = true })
        end,
        desc = "Dismiss all Notifications",
      },
    },
    opts = {
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      background_colour = "#1e222a",
      render = "minimal",
    },
    init = function()
      local banned_messages = { "No information available" }
      vim.notify = function(msg, ...)
        for _, banned in ipairs(banned_messages) do
          if msg == banned then
            return
          end
        end
        return require("notify")(msg, ...)
      end
    end,
  },
  -- Make folds look Prettier
  {
    "kevinhwang91/nvim-ufo",
    dependencies = {
      "kevinhwang91/promise-async",
    },
    opts = {
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("   %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0

        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end

        table.insert(newVirtText, { suffix, "MoreMsg" })

        return newVirtText
      end,
      close_fold_kinds = { "imports" },
    },
  },
}
