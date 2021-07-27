local opt = vim.opt
local cmd = vim.cmd
local g = vim.g
local fn = vim.fn
local api = vim.api
local map = require('utils').map

local plugLoad = fn['functions#PlugLoad']
local plugBegin = fn['plug#begin']
local plugEnd = fn['plug#end']

plugLoad()
-- cmd('call functions#PlugLoad()')
plugBegin('~/.config/nvim/plugged')

-- NOTE: the argument passed to Plug has to be wrapped with single-quotes

-- easy commenting
cmd [[Plug 'tpope/vim-commentary']]

-- mappings to easily delete, change and add such surroundings in pairs, such as quotes, parens, etc.
cmd [[Plug 'tpope/vim-surround']]

-- endings for html, xml, etc. - ehances surround
cmd [[Plug 'tpope/vim-ragtag']]

-- enables repeating other supported plugins with the . command
cmd [[Plug 'tpope/vim-repeat']]

-- single/multi line code handler: gS - split one line into multiple, gJ - combine multiple lines into one
cmd [[Plug 'AndrewRadev/splitjoin.vim']]

-- detect indent style (tabs vs. spaces)
cmd [[Plug 'tpope/vim-sleuth']]

-- Startify: Fancy startup screen for vim {{{
cmd "Plug 'mhinz/vim-startify'"
g.startify_files_number = 10
g.startify_change_to_dir = 0
g.ascii = {
  [[          ____                                         ]],
  [[         /___/\_                                       ]],
  [[        _\   \/_/\__                     __            ]],
  [[      __\       \/_/\            .--.--.|__|.--.--.--. ]],
  [[      \   __    __ \ \           |  |  ||  ||        | ]],
  [[     __\  \_\   \_\ \ \   __      \___/ |__||__|__|__| ]],
  [[    /_/\\   __   __  \ \_/_/\                          ]],
  [[    \_\/_\__\/\__\/\__\/_\_\/                          ]],
  [[       \_\/_/\       /_\_\/                            ]],
  [[          \_\/       \_\/                              ]]
}

-- g.startify_custom_header = 'startify#center(g:ascii)'
g.startify_custom_header = g.ascii
g.startify_relative_path  = 1
startify_use_env = 1

g.startify_lists = {
    { type = 'dir', header = { 'Recent Files ' } },
    { type = 'sessions',  header = { 'Sessions' }       },
    { type = 'bookmarks', header = { 'Bookmarks' }      },
    { type = 'commands',  header = { 'Commands' }       },
}

g.startify_commands = {
    { up = { 'Update Plugins', ':PlugUpdate' }},
    { ug = { 'Upgrade Plugin Manager', ':PlugUpgrade' }},
    { ts = { "Update Treesitter", "TSUpdate" }},
    { ch = { "Check Health", "checkhealth" }}
}

g.startify_bookmarks = {
    { c = '~/.config/nvim/init.vim' },
    { g = '~/.gitconfig' },
    { z = '~/.zshrc' }
}
map('n', '<leader>st', ':Startify<cr>')

-- fugitive
cmd [[Plug 'tpope/vim-fugitive']]
cmd [[Plug 'tpope/vim-rhubarb']]
map('n', '<leader>gr', ':Gread<cr>')
map('n', '<leader>gb', ':G blame<cr>')

-- general plugins
-- emmet support for vim - easily create markdup wth CSS-like syntax
cmd [[Plug 'mattn/emmet-vim']]

-- match tags in html, similar to paren support
cmd [[Plug 'gregsexton/MatchTag', { 'for': 'html' }]]

-- html5 support
cmd [[Plug 'othree/html5.vim', { 'for': 'html' }]]

-- mustache support
cmd [[Plug 'mustache/vim-mustache-handlebars']]

-- pug / jade support
cmd [[Plug 'digitaltoad/vim-pug', { 'for': ['jade', 'pug'] }]]

-- nunjucks support
cmd [[Plug 'niftylettuce/vim-jinja']]

-- liquid support
cmd [[Plug 'tpope/vim-liquid']]

cmd [[Plug 'othree/yajs.vim', { 'for': [ 'javascript', 'javascript.jsx', 'html' ] }]]
-- Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx', 'html'] }
cmd [[Plug 'moll/vim-node', { 'for': 'javascript' }]]
cmd [[Plug 'ternjs/tern_for_vim', { 'for': ['javascript', 'javascript.jsx'], 'do': 'npm install' }]]
cmd [[Plug 'MaxMEllon/vim-jsx-pretty']]
g.vim_jsx_pretty_highlight_close_tag = 1
cmd [[Plug 'leafgarland/typescript-vim', { 'for': ['typescript', 'typescript.tsx'] }]]

cmd [[Plug 'wavded/vim-stylus', { 'for': ['stylus', 'markdown'] }]]
cmd [[Plug 'groenewege/vim-less', { 'for': 'less' }]]
cmd [[Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }]]
cmd [[Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }]]
cmd [[Plug 'stephenway/postcss.vim', { 'for': 'css' }]]

cmd("Plug 'tpope/vim-markdown', { 'for': 'markdown' }")
g.markdown_fenced_languages = { tsx = 'typescript.tsx'  }

-- Open markdown files in Marked.app - mapped to <leader>m
cmd [[Plug 'itspriddle/vim-marked', { 'for': 'markdown', 'on': 'MarkedOpen' }]]
map('n', '<leader>m', ':MarkedOpen!<cr>')
map('n', '<leader>mq', ':MarkedQuit<cr>')
map('n', '<leader>*', '*<c-o>:%s///gn<cr>')

cmd [[Plug 'elzr/vim-json', { 'for': 'json' }]]
g.vim_json_syntax_conceal = 0

cmd [[Plug 'ekalinin/Dockerfile.vim']]
cmd [[Plug 'jparise/vim-graphql']]

-- Lua plugins
cmd [[Plug 'kyazdani42/nvim-web-devicons']]
cmd [[Plug 'nvim-lua/plenary.nvim']]
cmd [[Plug 'kyazdani42/nvim-tree.lua']]
cmd [[Plug 'lewis6991/gitsigns.nvim']]
cmd [[Plug 'neovim/nvim-lspconfig']]
cmd [[Plug 'hrsh7th/nvim-compe']]
cmd [[Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}]]
cmd [[Plug 'onsails/lspkind-nvim']]
cmd [[Plug 'RRethy/nvim-base16']]
cmd [[Plug 'glepnir/galaxyline.nvim' , {'branch': 'main'}]]
cmd [[Plug 'windwp/nvim-autopairs']]
cmd [[Plug 'mhartington/formatter.nvim']]
cmd [[Plug 'alvarosevilla95/luatab.nvim']]

require('fzf')

plugEnd()

require('lsp-config')
require('completion')
require('treesitter')
require('nvimtree')
require('git')
require('statusline')
require('nvim-autopairs').setup()
require('formatter-setup')
require('tabline')
