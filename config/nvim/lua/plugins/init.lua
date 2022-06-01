local g = vim.g
local fn = vim.fn
local utils = require("utils")
local nmap = utils.nmap
local env = vim.env
local cmd = vim.cmd

local plugLoad = fn["functions#PlugLoad"]
local plugBegin = fn["plug#begin"]
local plugEnd = fn["plug#end"]
local Plug = fn["plug#"]

plugLoad()
plugBegin("~/.config/nvim/plugged")

-- NOTE: the argument passed to Plug has to be wrapped with single-quotes

-- a set of lua helpers that are used by other plugins
Plug "nvim-lua/plenary.nvim"

-- easy commenting
Plug "tpope/vim-commentary"
Plug "JoosepAlviste/nvim-ts-context-commentstring"

-- bracket mappings for moving between buffers, quickfix items, etc.
Plug "tpope/vim-unimpaired"

-- mappings to easily delete, change and add such surroundings in pairs, such as quotes, parens, etc.
Plug "tpope/vim-surround"

-- endings for html, xml, etc. - ehances surround
Plug "tpope/vim-ragtag"

-- substitution and abbreviation helpers
Plug "tpope/vim-abolish"

-- enables repeating other supported plugins with the . command
Plug "tpope/vim-repeat"

-- single/multi line code handler: gS - split one line into multiple, gJ - combine multiple lines into one
Plug "AndrewRadev/splitjoin.vim"

-- detect indent style (tabs vs. spaces)
Plug "tpope/vim-sleuth"

-- setup editorconfig
Plug "editorconfig/editorconfig-vim"

-- fugitive
Plug "tpope/vim-fugitive"
Plug "tpope/vim-rhubarb"
nmap("<leader>gr", ":Gread<cr>")
nmap("<leader>gb", ":G blame<cr>")

-- general plugins
-- emmet support for vim - easily create markdup wth CSS-like syntax
Plug "mattn/emmet-vim"

-- match tags in html, similar to paren support
Plug("gregsexton/MatchTag", {["for"] = "html"})

-- html5 support
Plug("othree/html5.vim", {["for"] = "html"})

-- mustache support
Plug "mustache/vim-mustache-handlebars"

-- pug / jade support
Plug("digitaltoad/vim-pug", {["for"] = {"jade", "pug"}})

-- nunjucks support
-- Plug "niftylettuce/vim-jinja"

-- edit quickfix list
Plug "itchyny/vim-qfedit"

-- liquid support
Plug "tpope/vim-liquid"

Plug("othree/yajs.vim", {["for"] = {"javascript", "javascript.jsx", "html"}})
-- Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx', 'html'] }
Plug("moll/vim-node", {["for"] = "javascript"})
Plug "MaxMEllon/vim-jsx-pretty"
g.vim_jsx_pretty_highlight_close_tag = 1
Plug("leafgarland/typescript-vim", {["for"] = {"typescript", "typescript.tsx"}})

Plug("wavded/vim-stylus", {["for"] = {"stylus", "markdown"}})
Plug("groenewege/vim-less", {["for"] = "less"})
Plug("hail2u/vim-css3-syntax", {["for"] = "css"})
Plug("cakebaker/scss-syntax.vim", {["for"] = "scss"})
Plug("stephenway/postcss.vim", {["for"] = "css"})
Plug "udalov/kotlin-vim"

-- Open markdown files in Marked.app - mapped to <leader>m
Plug("itspriddle/vim-marked", {["for"] = "markdown", on = "MarkedOpen"})
nmap("<leader>m", ":MarkedOpen!<cr>")
nmap("<leader>mq", ":MarkedQuit<cr>")
nmap("<leader>*", "*<c-o>:%s///gn<cr>")

Plug("elzr/vim-json", {["for"] = "json"})
g.vim_json_syntax_conceal = 0

Plug "ekalinin/Dockerfile.vim"
Plug "jparise/vim-graphql"

Plug "hrsh7th/cmp-vsnip"
Plug "hrsh7th/vim-vsnip"
Plug "hrsh7th/vim-vsnip-integ"
local snippet_dir = os.getenv("DOTFILES") .. "/config/nvim/snippets"
g.vsnip_snippet_dir = snippet_dir
g.vsnip_filetypes = {
  javascriptreact = {"javascript"},
  typescriptreact = {"typescript"},
  ["typescript.tsx"] = {"typescript"}
}

-- add color highlighting to hex values
Plug "norcalli/nvim-colorizer.lua"

-- use devicons for filetypes
Plug "kyazdani42/nvim-web-devicons"

-- fast lau file drawer
Plug "kyazdani42/nvim-tree.lua"

-- Show git information in the gutter
Plug "lewis6991/gitsigns.nvim"

-- Helpers to configure the built-in Neovim LSP client
Plug "neovim/nvim-lspconfig"

-- Helpers to install LSPs and maintain them
Plug "williamboman/nvim-lsp-installer"

-- neovim completion
Plug "hrsh7th/cmp-nvim-lsp"
Plug "hrsh7th/cmp-nvim-lua"
Plug "hrsh7th/cmp-buffer"
Plug "hrsh7th/cmp-path"
Plug "hrsh7th/nvim-cmp"

-- treesitter enables an AST-like understanding of files
Plug("nvim-treesitter/nvim-treesitter", {["do"] = ":TSUpdate"})
-- show treesitter nodes
Plug "nvim-treesitter/playground"
-- enable more advanced treesitter-aware text objects
Plug "nvim-treesitter/nvim-treesitter-textobjects"
-- add rainbow highlighting to parens and brackets
Plug "p00f/nvim-ts-rainbow"

-- show nerd font icons for LSP types in completion menu
Plug "onsails/lspkind-nvim"

-- base16 syntax themes that are neovim/treesitter-aware
Plug "RRethy/nvim-base16"

-- status line plugin
Plug "feline-nvim/feline.nvim"

-- automatically complete brackets/parens/quotes
Plug "windwp/nvim-autopairs"

-- Run prettier and other formatters on save
Plug "mhartington/formatter.nvim"

-- Style the tabline without taking over how tabs and buffers work in Neovim
Plug "alvarosevilla95/luatab.nvim"

-- enable copilot support for Neovim
Plug "github/copilot.vim"
-- if a copilot-aliased version of node exists from fnm, use that
local copilot_node_command = env.FNM_DIR .. "/aliases/copilot/bin/node"
if utils.file_exists(copilot_node_command) then
  -- vim.g.copilot_node_command = copilot_node_path
  -- for some reason, this works but the above line does not
  cmd('let g:copilot_node_command = "' .. copilot_node_command .. '"')
end

-- improve the default neovim interfaces, such as refactoring
Plug "stevearc/dressing.nvim"

-- Navigate a code base with a really slick UI
Plug "nvim-telescope/telescope.nvim"
Plug "nvim-telescope/telescope-rg.nvim"

-- Startup screen for Neovim
Plug "startup-nvim/startup.nvim"

-- fzf
Plug "$HOMEBREW_PREFIX/opt/fzf"
Plug "junegunn/fzf.vim"
-- Power telescope with FZF
Plug("nvim-telescope/telescope-fzf-native.nvim", {["do"] = "make"})

Plug "folke/trouble.nvim"

Plug "navarasu/onedark.nvim"
Plug("catppuccin/nvim", {["as"] = "catppuccin"})
Plug "b0o/incline.nvim"

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
require("plugins.catppuccin")
require("plugins.startup")
require("incline").setup {
  hide = {
    cursorline = false,
    focused_win = false,
    only_win = true
  }
}
-- require("plugins.onedark")
