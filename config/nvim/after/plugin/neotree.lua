-- Unless you are still migrating, remove the deprecated commands from v1.x
vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])
local icons = require("theme").icons

require("neo-tree").setup({
  -- don't reset the cursor position when opening a file
  disable_netrw = true,
  hijack_netrw = true,
  close_if_last_window = false, -- Close Neo-tree if it is the last window left in the tab
  popup_border_style = "rounded",
  enable_git_status = true,
  enable_diagnostics = true,
  sort_case_insensitive = false, -- used when sorting files and directories in the tree
  use_default_mappings = false,
  sort_function = nil, -- use a custom function for sorting files and directories in the tree
  -- sort_function = function (a,b)
  --       if a.type == b.type then
  --           return a.path > b.path
  --       else
  --           return a.type > b.type
  --       end
  --   end , -- this sorts files and directories descendantly
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
        added = icons.added, -- or "✚", but this is redundant info if you use git_status_colors on the name
        modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
        deleted = icons.deleted, -- this can only be used in the git_status source
        renamed = icons.renamed, -- this can only be used in the git_status source
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
        -- ".DS_Store",
        -- "thumbs.db"
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
})

vim.keymap.set("n", "<leader>k", ":Neotree toggle reveal<cr>")
