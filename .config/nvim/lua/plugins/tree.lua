local g = vim.g
local map = vim.api.nvim_set_keymap

g.nvim_tree_side = 'left' -- left by default
g.nvim_tree_width = 30 -- 30 by default
g.nvim_tree_ignore = {'.git', 'node_modules', '.cache'} -- empty by default
g.nvim_tree_gitignore = 0 -- 0 by default
g.nvim_tree_auto_open = 0 -- 0 by default, opens the tree when typing `vim $DIR` or `vim`
g.nvim_tree_auto_close = 1 -- 0 by default, closes the tree when it's the last window
g.nvim_tree_auto_ignore_ft = {'startify', 'dashboard'} -- empty by default, don't auto open tree on specific filetypes.
g.nvim_tree_quit_on_open = 0 -- 0 by default, closes the tree when you open a file
g.nvim_tree_follow = 1 -- 0 by default, this option allows the cursor to be updated when entering a buffer
g.nvim_tree_indent_markers = 1 -- 0 by default, this option shows indent markers when folders are open
g.nvim_tree_hide_dotfiles = 1 -- 0 by default, this option hides files and folders starting with a dot `.`
g.nvim_tree_git_hl = 0 -- 0 by default, will enable file highlight for git attributes (can be used without the icons).
g.nvim_tree_highlight_opened_files = 0 -- 0 by default, will enable folder and file icon highlight for opened files/directories.
g.nvim_tree_root_folder_modifier = ':~' -- This is the default. See :help filename-modifiers for more options
g.nvim_tree_tab_open = 0 -- 0 by default, will open the tree when entering a new tab and the tree was previously open
g.nvim_tree_width_allow_resize = 1 -- 0 by default, will not resize the tree when opening a file
g.nvim_tree_disable_netrw = 1 -- 1 by default, disables netrw
g.nvim_tree_hijack_netrw = 1 -- 1 by default, prevents netrw from automatically opening when opening directories (but lets you keep its other utilities)
g.nvim_tree_add_trailing = 0 -- 0 by default, append a trailing slash to folder names
g.nvim_tree_group_empty = 0 -- 0 by default, compact folders that only contain a single folder into one node in the file tree
g.nvim_tree_lsp_diagnostics = 0 -- 0 by default, will show lsp diagnostics in the signcolumn. See :help nvim_tree_lsp_diagnostics
g.nvim_tree_disable_window_picker = 0 -- 0 by default, will disable the window picker.
g.nvim_tree_special_files = {'README.md', 'Makefile', 'MAKEFILE'} -- List of filenames that gets highlighted with NvimTreeSpecialFile
g.nvim_tree_show_icons = {git = 0, folders = 1, files = 1}

map('n', '<leader>c', ':<C-U>NvimTreeToggle<CR>', {noremap = true})
