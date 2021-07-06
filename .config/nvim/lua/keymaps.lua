local map = vim.api.nvim_set_keymap
local exec = vim.api.nvim_exec
local fn = vim.fn
local o = vim.o

vim.g.mapleader = ' ' -- 'vim.g' sets global variables

map('n', '<bs>', '<c-^>', {noremap = true})

map('n', '<A-j>', ':m .+1<CR>==', {noremap = true})
map('n', '<A-k>', ':m .-2<CR>==', {noremap = true})
map('i', '<A-j>', '<Esc>:m .+1<CR>==gi', {noremap = true})
map('i', '<A-k>', '<Esc>:m .-2<CR>==gi', {noremap = true})
map('v', '<A-j>', ':m \'>+1<CR>gv=gv', {noremap = true})
map('v', '<A-k>', ':m \'<-2<CR>gv=gv', {noremap = true})

-- ^ - jump to the first non-blank character of the line
map('n', 'H', '^', {noremap = true})
map('v', 'H', '^', {noremap = true})
-- g_ - jump to the end of the line
map('n', 'L', 'g_', {noremap = true})
map('v', 'L', 'g_', {noremap = true})

-- map('n', '<silent> *', ":let @/ = '\<'.expand('<cword>').'\>'\|set hlsearch<C-M>", {})
map('n', '<C-C>', ':noh<CR>:ccl<CR><esc>', {silent = true})
map('i', '<C-C>', '<esc><C-C>', {silent = true})
map('v', '<C-C>', '<esc><C-C>', {silent = true})

map('n', '*', [[:let @/ = '\<'.expand('<cword>').'\>' | set hlsearch <CR>]],
    {silent = true})
map('v', [[//]], [[y/\V<C-R>=escape(@",'/\')<CR><CR>]], {noremap = true})

function _G.RgCurrentWord()
    local wordUnderCursor = vim.fn.expand('<cword>')
    exec('Rg ' .. wordUnderCursor, false)
end

map('n', '<leader>R', ':lua RgCurrentWord()<CR>',
    {noremap = true, silent = true})

function _G.RgCurrentSelected()
    local _, line_start, column_start, _ = unpack(vim.fn.getpos('\'<'))
    local _, line_end, column_end, _ = unpack(vim.fn.getpos('\'>'))
    local lines = fn.getline(line_start, line_end)
    if #lines == 0 then return end
    lines[#lines] = string.sub(lines[#lines], 0, column_end -
                                   (o.selection == 'inclusive' and 0 or 1))
    lines[1] = string.sub(lines[1], column_start)
    local currentSelected = table.concat(lines, '\n')
    dump(currentSelected)
    exec('Rg ' .. currentSelected, false)
end

map('v', '<leader>R', ':lua RgCurrentSelected()<CR>', {})

map('n', 'gt', ':tabedit<CR>', {noremap = true, silent = true})
map('n', 'g1', '1gt', {noremap = true, silent = true})
map('n', 'g2', '2gt', {noremap = true, silent = true})
map('n', 'g3', '3gt', {noremap = true, silent = true})
map('n', 'g4', '4gt', {noremap = true, silent = true})
map('n', 'g5', '5gt', {noremap = true, silent = true})
map('n', 'g6', '6gt', {noremap = true, silent = true})
map('n', 'g7', '7gt', {noremap = true, silent = true})
map('n', 'g8', '8gt', {noremap = true, silent = true})
map('n', 'g9', '9gt', {noremap = true, silent = true})

map('n', 'j', 'gj', {noremap = true, silent = true})
map('n', 'k', 'gk', {noremap = true, silent = true})

map('v', 'y', '"*y', {noremap = true})
-- map('v', 'p', '"*p', {noremap = true})
map('n', 'yy', '"*yy', {noremap = true})

map('n', '<leader>yp', ':let @* = expand("%") . ":" . line(".")<CR>',
    {noremap = true})
map('n', '<leader>yP', ':let @* = expand("%:p") . ":" . line(".")<CR>',
    {noremap = true})

map('n', '<leader>Fp',
    ':norm yy<CR>:let @* = expand("%") . ":" . line(".") . ":" . @"<CR>',
    {noremap = true, silent = true})
map('n', '<leader>FP',
    ':norm yy<CR>:let @* = expand("%:p") . ":" . line(".") . ":" . @"<CR>',
    {noremap = true, silent = true})

map('n', '<Leader>ev', ':<C-u>e $MYVIMRC<CR>', {noremap = true})
map('n', '<Leader>sv', ':<C-u>source $MYVIMRC<CR>', {noremap = true})
map('n', '<Leader>ec', ':<C-u>CocConfig<CR>', {noremap = true})

map('n', 'gV', '`[v`]', {noremap = true})
