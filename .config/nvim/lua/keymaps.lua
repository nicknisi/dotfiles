local map = vim.api.nvim_set_keymap

vim.g.mapleader = ' ' -- 'vim.g' sets global variables

-- backspace to switch recent file
map('n', '<bs>', '<c-^>', {noremap = true})

-- alt + jk to move line up/down
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

-- ctrl + c to turn off highlight and close quickfix windows and escape
map('n', '<C-C>', ':noh<CR>:ccl<CR><esc>', {silent = true})
--[[ map('i', '<C-C>', '<esc><C-C>', {silent = true})
map('v', '<C-C>', '<esc><C-C>', {silent = true}) ]]

-- * to highlight current word
map('n', '*', [[:let @/ = '\<'.expand('<cword>').'\>' | set hlsearch <CR>]],
    {silent = true})
-- // to highlight current sellected word
map('v', [[//]], [[y/\V<C-R>=escape(@",'/\')<CR><CR>]], {noremap = true})

-- navigate tab by g
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

-- move up/down without breaking column
map('n', 'j', 'gj', {noremap = true, silent = true})
map('n', 'k', 'gk', {noremap = true, silent = true})

-- copy to clipboard
map('v', 'y', '"*y', {noremap = true})
-- map('v', 'p', '"*p', {noremap = true})
-- copy line to clipboard
map('n', 'yy', '"*yy', {noremap = true})

-- copy current relative path /Users/chien.le/.config/nvim/lua/keymaps.lua:56
map('n', '<leader>yp', ':let @* = expand("%")<CR>',
    {noremap = true})
-- copy current absolute path /Users/chien.le/.config/nvim/lua/keymaps.lua:59
map('n', '<leader>yP', ':let @* = expand("%:p")<CR>',
    {noremap = true})

-- open/source config files
map('n', '<Leader>ev', ':<C-u>e $MYVIMRC<CR>', {noremap = true})
map('n', '<Leader>sv', ':<C-u>source $MYVIMRC<CR>', {noremap = true})

-- copy last pasted
map('n', 'gV', '`[v`]', {noremap = true})
