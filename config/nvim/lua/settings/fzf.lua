local opt = vim.opt
local cmd = vim.cmd
local env = vim.env
local g = vim.g
local fn = vim.fn
local api = vim.api
local map = require('utils').map

if (fn.isdirectory('.git')) then
    map('n', '<leader>t', ':GitFiles --cached --others --exclude-standard<cr>')
else
    map('n', '<leader>t', ':FZF<cr>')
end

map('n', '<leader>s', ':GFiles?<cr>')
map('n', '<leader>r', ':Buffers<cr>')
map('n', '<leader>e', ':FZF<cr>')

map('n', '<leader><tab>', '<plug>(fzf-maps-n)')
map('x', '<leader><tab>', '<plug>(fzf-maps-x)')
map('o', '<leader><tab>', '<plug>(fzf-maps-o)')

-- Insert mode completion
map('i', '<c-x><c-k>', '<plug>(fzf-complete-word)')
map('i', '<c-x><c-f>', '<plug>(fzf-complete-path)')
map('i', '<c-x><c-j>', '<plug>(fzf-complete-file-ag)')
map('i', '<c-x><c-l>', '<plug>(fzf-complete-line)')

vim.api.nvim_exec([[
command! FZFMru call fzf#run({ 'source':  v:oldfiles, 'sink':    'e', 'options': '-m -x +s', 'down':    '40%'})
command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --follow --color=always '.<q-args>.' || true', 1, <bang>0 ? fzf#vim#with_preview('up:60%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)
command! -bang -nargs=? -complete=dir Files call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
command! -bang -nargs=? -complete=dir GitFiles call fzf#vim#gitfiles(<q-args>, fzf#vim#with_preview(), <bang>0)
]], false)

function FloatingFZF()
    local lines = vim.o.lines
    local columns = vim.o.columns
    local buf = vim.api.nvim_create_buf(true, true)
    local height = fn.float2nr(lines * 0.5)
    local width = fn.float2nr(columns * 0.7)
    local horizontal = fn.float2nr((columns - width) / 2)
    local vertical = 0
    local opts = {
        relative = 'editor',
        row = vertical,
        col = horizontal,
        width = width,
        height = height,
        style = 'minimal'
    }
    vim.api.nvim_open_win(buf, true, opts)
end

local fzf_opts = {
    env.FZF_DEFAULT_OPTS or '',
    ' --layout=reverse',
    ' --pointer=" "',
    ' --info=hidden',
    ' --border=rounded'
}

env.FZF_DEFAULT_OPTS = table.concat(fzf_opts, '')

g.fzf_preview_window = { 'right:50%:hidden', '?' }
g.fzf_layout = { window = 'call v:lua.FloatingFZF()' }
