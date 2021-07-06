local g = vim.g
local o = vim.o
local api = vim.api
local map = vim.api.nvim_set_keymap

function _G.Float()
    local width = vim.fn.float2nr(o.columns * 0.8)
    local height = vim.fn.float2nr(o.lines * 0.6)
    local opts = {relative = 'editor', row = (o.lines - height) / 2, col = (o.columns - width) / 2, width = width, height = height}

    api.nvim_open_win(api.nvim_create_buf(false, true), true, opts)
end

g.fzf_layout = {window = 'lua Float()'}
g.fzf_command_prefix = 'Fzf'

map('n', '<leader>g', ':FzfGFiles<cr>', {})
map('n', '<leader>f', ':FzfFiles<cr>', {})
map('n', '<leader>r', ':FzfRg ', {})
map('n', '<leader>h', ':FzfHistory<cr>', {})
map('n', '<leader>m', ':FzfMaps<cr>', {})
map('n', '<leader>H', ':FzfHelptags!<cr>', {})
map('n', '<leader>C', ':Fzf<C-U>Commands!<cr>', {})
map('n', '<leader>l', ':Fzf<C-U>Lines<cr>', {})
