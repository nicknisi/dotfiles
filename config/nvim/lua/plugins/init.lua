local cmd = vim.cmd
local g = vim.g
local fn = vim.fn
local utils = require("utils")
local nmap = utils.nmap

local plugLoad = fn["functions#PlugLoad"]
local plugBegin = fn["plug#begin"]
local plugEnd = fn["plug#end"]

plugLoad()
-- cmd('call functions#PlugLoad()')
plugBegin("~/.config/nvim/plugged")

-- NOTE: the argument passed to Plug has to be wrapped with single-quotes

-- a set of lua helpers that are used by other plugins
cmd [[Plug 'nvim-lua/plenary.nvim']]

-- easy commenting
cmd [[Plug 'tpope/vim-commentary']]
cmd [[Plug 'JoosepAlviste/nvim-ts-context-commentstring']]

-- bracket mappings for moving between buffers, quickfix items, etc.
cmd [[Plug 'tpope/vim-unimpaired']]

-- mappings to easily delete, change and add such surroundings in pairs, such as quotes, parens, etc.
cmd [[Plug 'tpope/vim-surround']]

-- endings for html, xml, etc. - ehances surround
cmd [[Plug 'tpope/vim-ragtag']]

-- substitution and abbreviation helpers
cmd [[Plug 'tpope/vim-abolish']]

-- enables repeating other supported plugins with the . command
cmd [[Plug 'tpope/vim-repeat']]

-- single/multi line code handler: gS - split one line into multiple, gJ - combine multiple lines into one
cmd [[Plug 'AndrewRadev/splitjoin.vim']]

-- detect indent style (tabs vs. spaces)
cmd [[Plug 'tpope/vim-sleuth']]

-- setup editorconfig
cmd [[Plug 'editorconfig/editorconfig-vim']]

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

-- edit quickfix list
cmd [[Plug 'itchyny/vim-qfedit']]

-- liquid support
cmd [[Plug 'tpope/vim-liquid']]

cmd [[Plug 'othree/yajs.vim', { 'for': [ 'javascript', 'javascript.jsx', 'html' ] }]]
-- Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx', 'html'] }
cmd [[Plug 'moll/vim-node', { 'for': 'javascript' }]]
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

cmd [[Plug 'hrsh7th/cmp-vsnip']]
cmd [[Plug 'hrsh7th/vim-vsnip']]
cmd [[Plug 'hrsh7th/vim-vsnip-integ']]
local snippet_dir = os.getenv("DOTFILES") .. "/config/nvim/snippets"
g.vsnip_snippet_dir = snippet_dir
g.vsnip_filetypes = {
  javascriptreact = {"javascript"},
  typescriptreact = {"typescript"},
  ["typescript.tsx"] = {"typescript"}
}

-- add color highlighting to hex values
cmd [[Plug 'norcalli/nvim-colorizer.lua']]

-- use devicons for filetypes
cmd [[Plug 'kyazdani42/nvim-web-devicons']]

-- fast lau file drawer
cmd [[Plug 'kyazdani42/nvim-tree.lua']]

-- Show git information in the gutter
cmd [[Plug 'lewis6991/gitsigns.nvim']]

-- Helpers to configure the built-in Neovim LSP client
cmd [[Plug 'neovim/nvim-lspconfig']]

-- Helpers to install LSPs and maintain them
cmd [[Plug 'williamboman/nvim-lsp-installer']]

-- neovim completion
cmd [[Plug 'hrsh7th/cmp-nvim-lsp']]
cmd [[Plug 'hrsh7th/cmp-nvim-lua']]
cmd [[Plug 'hrsh7th/cmp-buffer']]
cmd [[Plug 'hrsh7th/cmp-path']]
cmd [[Plug 'hrsh7th/nvim-cmp']]

-- treesitter enables an AST-like understanding of files
cmd [[Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}]]
-- show treesitter nodes
cmd [[Plug 'nvim-treesitter/playground']]
-- enable more advanced treesitter-aware text objects
cmd [[Plug 'nvim-treesitter/nvim-treesitter-textobjects']]
-- add rainbow highlighting to parens and brackets
cmd [[Plug 'p00f/nvim-ts-rainbow']]

-- show nerd font icons for LSP types in completion menu
cmd [[Plug 'onsails/lspkind-nvim']]

-- base16 syntax themes that are neovim/treesitter-aware
cmd [[Plug 'RRethy/nvim-base16']]

-- status line plugin
cmd [[Plug 'feline-nvim/feline.nvim']]

-- automatically complete brackets/parens/quotes
cmd [[Plug 'windwp/nvim-autopairs']]

-- Run prettier and other formatters on save
cmd [[Plug 'mhartington/formatter.nvim']]

-- Style the tabline without taking over how tabs and buffers work in Neovim
cmd [[Plug 'alvarosevilla95/luatab.nvim']]

-- enable copilot support for Neovim
cmd [[Plug 'github/copilot.vim']]

-- improve the default neovim interfaces, such as refactoring
cmd [[Plug 'stevearc/dressing.nvim']]

-- Navigate a code base with a really slick UI
cmd [[Plug 'nvim-telescope/telescope.nvim']]

-- Startup screen for Neovim
cmd [[Plug 'startup-nvim/startup.nvim']]

-- fzf
cmd [[Plug $HOMEBREW_PREFIX . '/opt/fzf']]
cmd [[Plug 'junegunn/fzf.vim']]
-- Power telescope with FZF
cmd [[Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }]]

cmd [[Plug 'folke/trouble.nvim']]

plugEnd()

-- Once the plugins have been loaded, Lua-based plugins need to be required and started up
-- For plugins with their own configuration file, that file is loaded and is responsible for
-- starting them. Otherwise, the plugin itself is required and its `setup` method is called.
require("nvim-autopairs").setup()
require("colorizer").setup()
require("plugins.telescope")
require("plugins.gitsigns")
require("plugins.trouble")
require("plugins.fzf")
require("plugins.lspconfig")
require("plugins.completion")
require("plugins.treesitter")
require("plugins.nvimtree")
require("plugins.formatter")
require("plugins.tabline")
require("plugins.feline")
require("plugins.startup")
