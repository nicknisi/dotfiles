local opt = vim.opt
local cmd = vim.cmd
local g = vim.g
local fn = vim.fn
local api = vim.api
local utils = require("utils")
local nmap = utils.nmap

local plugLoad = fn["functions#PlugLoad"]
local plugBegin = fn["plug#begin"]
local plugEnd = fn["plug#end"]

plugLoad()
-- cmd('call functions#PlugLoad()')
plugBegin("~/.config/nvim/plugged")

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

-- fugitive
cmd [[Plug 'tpope/vim-fugitive']]
cmd [[Plug 'tpope/vim-rhubarb']]
nmap("<leader>gr", ":Gread<cr>")
nmap("<leader>gb", ":G blame<cr>")

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
cmd [[Plug 'udalov/kotlin-vim']]

cmd("Plug 'tpope/vim-markdown', { 'for': 'markdown' }")
g.markdown_fenced_languages = {tsx = "typescript.tsx"}

-- Open markdown files in Marked.app - mapped to <leader>m
cmd [[Plug 'itspriddle/vim-marked', { 'for': 'markdown', 'on': 'MarkedOpen' }]]
nmap("<leader>m", ":MarkedOpen!<cr>")
nmap("<leader>mq", ":MarkedQuit<cr>")
nmap("<leader>*", "*<c-o>:%s///gn<cr>")

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
cmd [[Plug 'kabouzeid/nvim-lspinstall']]
cmd [[Plug 'hrsh7th/nvim-compe']]
cmd [[Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}]]
cmd [[Plug 'onsails/lspkind-nvim']]
cmd [[Plug 'RRethy/nvim-base16']]
cmd [[Plug 'glepnir/galaxyline.nvim' , {'branch': 'main'}]]
cmd [[Plug 'windwp/nvim-autopairs']]
cmd [[Plug 'mhartington/formatter.nvim']]
cmd [[Plug 'alvarosevilla95/luatab.nvim']]

-- fzf
cmd [[Plug $HOMEBREW_PREFIX . '/opt/fzf']]
cmd [[Plug 'junegunn/fzf.vim']]

cmd [[Plug 'folke/trouble.nvim']]

plugEnd()

require("nvim-autopairs").setup()
require("settings.gitsigns")
require("settings.trouble")
require("settings.fzf")
require("settings.lspconfig")
require("settings.completion")
require("settings.treesitter")
require("settings.nvimtree")
require("settings.galaxyline")
require("settings.formatter")
require("settings.tabline")
require("settings.startify")
