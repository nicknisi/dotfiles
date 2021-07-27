-- init.lua
-- Neovim-specific configuration

local opt = vim.opt
local cmd = vim.cmd
local g = vim.g
local fn = vim.fn
local api = vim.api
local map = require('utils').map

-- General
----------------------------------------------------------------
-- TODO: How do you set abbr using Lua?
cmd [[abbr funciton function]]
cmd [[abbr teh the]]
cmd [[abbr tempalte template]]
cmd [[abbr fitler filter]]
cmd [[abbr cosnt const]]
cmd [[abbr attribtue attribute]]
cmd [[abbr attribuet attribute]]

opt.backup = false                     -- don't use backup files
opt.writebackup = false                -- don't backup the file while editing
opt.swapfile = false                   -- don't create swap files for new buffers
opt.updatecount = 0                    -- don't write swap files after some number of updates

opt.backupdir = {
  '~/.vim-tmp',
  '~/.tmp',
  '~/tmp',
  '/var/tmp',
  '/tmp'
}

opt.directory = {
  '~/.vim-tmp',
  '~/.tmp',
  '~/tmp',
  '/var/tmp',
  '/tmp'
}

opt.history = 1000                     -- store the last 1000 commands entered
opt.textwidth = 120                    -- after configured number of characters, wrap line

opt.inccommand = 'nosplit'             -- show the results of substition as they're happening
                                           -- but don't open a split

opt.backspace = {'indent','eol,start'}     -- make backspace behave in a sane manner
opt.clipboard = {'unnamed','unnamedplus'}  -- use the system clipboard
opt.mouse = 'a'                        -- set mouse mode to all modes

-- searching
opt.ignorecase = true                  -- case insensitive searching
opt.smartcase = true                   -- case-sensitive if expresson contains a capital letter
opt.hlsearch = true                    -- highlight search results
opt.incsearch = true                   -- set incremental search, like modern browsers
opt.lazyredraw = false                 -- don't redraw while executing macros

opt.magic = true                       -- set magic on, for regular expressions

-- error bells
opt.errorbells = false
opt.visualbell = true
opt.timeoutlen = 500

-- Appearance
---------------------------------------------------------
opt.number = true -- show line numbers
opt.wrap = true -- turn on line wrapping
opt.wrapmargin = 8 -- wrap lines when coming within n characters from side
opt.linebreak = true -- set soft wrapping
opt.showbreak= '↪'
opt.autoindent = true -- automatically set indent of new line
opt.ttyfast = true -- faster redrawing
table.insert(opt.diffopt, 'vertical')
table.insert(opt.diffopt, 'iwhite')
table.insert(opt.diffopt, 'internal')
table.insert(opt.diffopt, 'algorithm:patience')
table.insert(opt.diffopt, 'hiddenoff')
opt.laststatus = 2 -- show the status line all the time
opt.so = 7 -- set 7 lines to the cursors - when moving vertical
opt.wildmenu = true -- enhanced command line completion
opt.hidden = true -- current buffer can be put into background
opt.showcmd = true -- show incomplete commands
opt.showmode = true -- don't show which mode disabled for PowerLine
opt.wildmode= {'list','longest'} -- complete files like a shell
-- opt.shell=$SHELL -- TODO: how to do this?
opt.cmdheight = 1 -- command bar height
opt.title = true -- set terminal title
opt.showmatch = true -- show matching braces
opt.mat = 2 -- how many tenths of a second to blink
opt.updatetime = 300
opt.signcolumn = 'yes'
opt.shortmess = 'atToOFc' -- prompt message options

-- Tab control
opt.smarttab = true -- tab respects 'tabstop', 'shiftwidth', and 'softtabstop'
opt.tabstop = 4 -- the visible width of tabs
opt.softtabstop = 4 -- edit as if the tabs are 4 characters wide
opt.shiftwidth = 4 -- number of spaces to use for indent and unindent
opt.shiftround = true -- round indent to a multiple of 'shiftwidth'

-- code folding settings
opt.foldmethod = 'syntax' -- fold based on indent
opt.foldlevelstart = 99
opt.foldnestmax = 10 -- deepest fold is 10 levels
opt.foldenable = false -- don't fold by default
opt.foldlevel = 1

-- toggle invisible characters
opt.list  =  true
opt.listchars = {
    tab = '→ ',
    eol = '¬',
    trail = '⋅',
    extends = '❯',
    precedes = '❮'
}

-- Mappings
g.mapleader = ','
opt.pastetoggle = '<leader>v'

map('i', 'jk', '<Esc>')
map('n', '<leader>,', ':w<cr>')
map('n', '<space>', ':set hlsearch! hlsearch?<cr>')

map('n', '<leader><space>', [[:%s/\s\+$<cr>]])
map('n', '<leader><space><space>', [[:%s/\n\{2,}/\r\r/g<cr>]])

map('n', '<leader>l', ':set list!<cr>')
map('n', '<c-j>', 'pumvisible() ? "<C-N>" : "<C-j>"', { expr = true, noremap = true })
map('n', '<c-k>', 'pumvisible() ? "<C-P>" : "<C-k>"', { expr = true, noremap = true })
map('v', '<', '<gv')
map('v', '>', '>gv')
map('n', '<leader>.', '<c-^>')
map('v', '.', ':normal .<cr>')

map('n', '<C-h>', '<Plug>WinMoveLeft')
map('n', '<C-j>', '<Plug>WinMoveDown')
map('n', '<C-k>', '<Plug>WinMoveUp')
map('n', '<C-l>', '<Plug>WinMoveRight')

map('n', '<leader>z', '<Plug>Zoom')

-- move line mappings
-- ∆ is <A-j> on macOS
-- ˚ is <A-k> on macOS
map('n', '∆', ':m .+1<cr>==')
map('n', '˚', ':m .-2<cr>==')
map('i', '∆', '<Esc>:m .+1<cr>==gi')
map('i', '˚', '<Esc>:m .-2<cr>==gi')
map('v', '∆', ":m '>+1<cr>gv=gv")
map('v', '˚', ":m '<-2<cr>gv=gv")

map('n', '<leader>i', ':set cursorline!')

-- scroll the viewport faster
map('n', '<C-e>', '3<c-e>', { noremap = true })
map('n', '<C-y>', '3<c-y>', { noremap = true })

-- moving up and down work as you would expect
map('n', 'j', 'v:count == 0 ? "gj" : "j"', { expr = true, noremap = true })
map('n', 'k', 'v:count == 0 ? "gk" : "k"', { expr = true, noremap = true })
map('n', '^', 'v:count == 0 ? "g^" :  "^"', { expr = true, noremap = true })
map('n', '$', 'v:count == 0 ? "g$" : "$"', { expr = true, noremap = true })

-- custom text objects
-- inner-line
map('x',  'il', ':<c-u>normal! g_v^<cr>')
map('o',  'il', ':<c-u>normal! g_v^<cr>')
-- around line
map('v',  'al', ':<c-u>normal! $v0<cr>')
map('o',  'al', ':<c-u>normal! $v0<cr>')

-- interesting word mappings
map('n', '<leader>0', '<Plug>ClearInterestingWord')
map('n', '<leader>1', '<Plug>HiInterestingWord1')
map('n', '<leader>2', '<Plug>HiInterestingWord2')
map('n', '<leader>3', '<Plug>HiInterestingWord3')
map('n', '<leader>4', '<Plug>HiInterestingWord4')
map('n', '<leader>5', '<Plug>HiInterestingWord5')
map('n', '<leader>6', '<Plug>HiInterestingWord6')

-- open current buffer in a new tab
map('n', 'gTT', ':tab sb<cr>', { silent = true })

require('plugins')

if fn.filereadable(fn.expand('~/.vimrc_background')) then
    g.base16colorspace=256
    cmd [[source ~/.vimrc_background]]
end

cmd [[syntax on]]
cmd [[filetype plugin indent on]]

cmd [[syntax on]]
cmd [[filetype plugin indent on]]
-- make the highlighting of tabs and other non-text less annoying
cmd [[highlight SpecialKey ctermfg=19 guifg=#333333]]
cmd [[highlight NonText ctermfg=19 guifg=#333333]]

-- make comments and HTML attributes italic
cmd [[highlight Comment cterm=italic term=italic gui=italic]]
cmd [[highlight htmlArg cterm=italic term=italic gui=italic]]
cmd [[highlight xmlAttrib cterm=italic term=italic gui=italic]]
-- highlight Type cterm=italic term=italic gui=italic
cmd [[highlight Normal ctermbg=none]]
