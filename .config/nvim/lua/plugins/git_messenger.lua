local g = vim.g
local map = vim.api.nvim_set_keymap

g.git_messenger_no_default_mappings = true

map('n', 'M', '<Plug>(git-messenger)', {})
