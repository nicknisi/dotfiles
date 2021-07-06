local g = vim.g
local exec = vim.api.nvim_exec
local map = vim.api.nvim_set_keymap

g.gitgutter_map_keys = 0
g.gitgutter_preview_win_floating = 0

g.gitgutter_sign_added = '▌'
g.gitgutter_sign_modified = '▌'
g.gitgutter_sign_removed = '▁'
g.gitgutter_sign_removed_first_line = '▌'
g.gitgutter_sign_modified_removed = '▌'
g.gitgutter_realtime = 1

exec([[
highlight GitGutterDelete guifg=#F97CA9
highlight GitGutterAdd    guifg=#BEE275
highlight GitGutterChange guifg=#96E1EF
]], false)

map('n', '<leader>b', ':<C-U>Git blame<cr>', {noremap = true})
map('n', ']h', '<Plug>(GitGutterNextHunk)', {})
map('n', '[h', '<Plug>(GitGutterPrevHunk)', {})
map('n', 'ghs', '<Plug>(GitGutterStageHunk)', {})
map('n', 'ghu', '<Plug>(GitGutterUndoHunk)', {})
map('n', 'ghp', '<Plug>(GitGutterPreviewHunk)', {})
