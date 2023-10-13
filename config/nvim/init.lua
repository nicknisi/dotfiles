-- init.lua
-- Neovim-specific configuration
--
require("globals")
local opt = vim.opt
local cmd = vim.cmd
local g = vim.g
local o = vim.o
local fn = vim.fn
local env = vim.env
local utils = require("utils")
local termcodes = utils.termcodes
local nmap = utils.nmap
local vmap = utils.vmap
local imap = utils.imap
local xmap = utils.xmap
local omap = utils.omap
local nnoremap = utils.nnoremap
local inoremap = utils.inoremap
local vnoremap = utils.vnoremap
local icons = require("theme").icons
local current_theme = require("theme").get_current_theme()

-- create a completion_nvim table on _G which is visible via
-- v:lua from vimscript
_G.completion_nvim = {}

function _G.completion_nvim.smart_pumvisible(vis_seq, not_vis_seq)
  if fn.pumvisible() == 1 then
    return termcodes(vis_seq)
  else
    return termcodes(not_vis_seq)
  end
end

-- General
----------------------------------------------------------------
cmd([[abbr funciton function]])
cmd([[abbr teh the]])
cmd([[abbr tempalte template]])
cmd([[abbr fitler filter]])
cmd([[abbr cosnt const]])
cmd([[abbr attribtue attribute]])
cmd([[abbr attribuet attribute]])

opt.backup = false -- don't use backup files
opt.writebackup = false -- don't backup the file while editing
opt.swapfile = false -- don't create swap files for new buffers
opt.updatecount = 0 -- don't write swap files after some number of updates

opt.backupdir = { "~/.vim-tmp", "~/.tmp", "~/tmp", "/var/tmp", "/tmp" }

opt.directory = { "~/.vim-tmp", "~/.tmp", "~/tmp", "/var/tmp", "/tmp" }

opt.history = 1000 -- store the last 1000 commands entered
opt.textwidth = 120 -- after configured number of characters, wrap line

-- show the results of substition as they're happening but don't open a split
opt.inccommand = "nosplit"

opt.backspace = { "indent", "eol,start" } -- make backspace behave in a sane manner
opt.clipboard = { "unnamed", "unnamedplus" } -- use the system clipboard
opt.mouse = "a" -- set mouse mode to all modes

-- searching
opt.ignorecase = true -- case insensitive searching
opt.smartcase = true -- case-sensitive if expresson contains a capital letter
opt.hlsearch = true -- highlight search results
opt.incsearch = true -- set incremental search, like modern browsers
opt.lazyredraw = false -- don't redraw while executing macros
opt.magic = true -- set magic on, for regular expressions

if fn.executable("rg") then
  -- if ripgrep installed, use that as a grepper
  opt.grepprg = "rg --vimgrep --no-heading"
  opt.grepformat = "%f:%l:%c:%m,%f:%l:%m"
  -- create autocmd to automatically open quickfix window when grepping
  cmd([[autocmd QuickFixCmdPost [^l]* nested cwindow]])
end

-- error bells
opt.errorbells = false
opt.visualbell = true
opt.timeoutlen = 500

-- Appearance
---------------------------------------------------------
o.termguicolors = true
opt.number = true -- show line numbers
opt.relativenumber = true
opt.wrap = true -- turn on line wrapping
opt.wrapmargin = 8 -- wrap lines when coming within n characters from side
opt.linebreak = true -- set soft wrapping
opt.showbreak = "↪"
opt.autoindent = true -- automatically set indent of new line
opt.ttyfast = true -- faster redrawing
table.insert(opt.diffopt, "vertical")
table.insert(opt.diffopt, "iwhite")
table.insert(opt.diffopt, "internal")
table.insert(opt.diffopt, "algorithm:patience")
table.insert(opt.diffopt, "hiddenoff")
opt.laststatus = 3 -- show the global statusline all the time
opt.scrolloff = 7 -- set 7 lines to the cursors - when moving vertical
opt.wildmenu = true -- enhanced command line completion
opt.hidden = true -- current buffer can be put into background
opt.showcmd = true -- show incomplete commands
opt.showmode = true -- don't show which mode disabled for PowerLine
opt.wildmode = { "list", "longest" } -- complete files like a shell
opt.shell = env.SHELL
opt.cmdheight = 0 -- hide command bar when not used
opt.title = true -- set terminal title
opt.showmatch = true -- show matching braces
opt.mat = 2 -- how many tenths of a second to blink
opt.updatetime = 300
opt.signcolumn = "yes"
opt.shortmess = "atToOFc" -- prompt message options

-- Tab control
opt.smarttab = true -- tab respects 'tabstop', 'shiftwidth', and 'softtabstop'
opt.tabstop = 4 -- the visible width of tabs
opt.softtabstop = 4 -- edit as if the tabs are 4 characters wide
opt.shiftwidth = 4 -- number of spaces to use for indent and unindent
opt.shiftround = true -- round indent to a multiple of 'shiftwidth'

-- code folding settings
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevelstart = 99
opt.foldnestmax = 10 -- deepest fold is 10 levels
opt.foldenable = false -- don't fold by default
opt.foldlevel = 1
-- fix code folding. Without this autocmd, the message "E490: No fold found" is displayed
-- anytime a fold is triggered, until the file is reloaded (for example, with `:e<cr>`)
-- https://github.com/nvim-telescope/telescope.nvim/issues/699#issuecomment-1159637962
-- vim.api.nvim_create_autocmd({ "BufEnter" }, { pattern = { "*" }, command = "normal zx" })

-- toggle invisible characters
opt.list = true
opt.listchars = {
  tab = "→ ",
  -- eol = "¬",
  trail = "⋅",
  extends = "❯",
  precedes = "❮",
}

-- hide the ~ character on empty lines at the end of the buffer
opt.fcs = "eob: "

-- Mappings
g.mapleader = ","
opt.pastetoggle = "<leader>v"

nnoremap("Q", "<nop>")
imap("jk", "<Esc>")
nmap("<leader>,", ":silent w<cr>")
nmap("<space>", ":silent set hlsearch! hlsearch?<cr>")

nmap("<leader><space>", [[:%s/\s\+$<cr>]])
nmap("<leader><space><space>", [[:%s/\n\{2,}/\r\r/g<cr>]])

nmap("<leader>l", ":set list!<cr>")
inoremap("<C-j>", [[v:lua.completion_nvim.smart_pumvisible('<C-n>', '<C-j>')]], { expr = true })
inoremap("<C-k>", [[v:lua.completion_nvim.smart_pumvisible('<C-p>', '<C-k>')]], { expr = true })
vmap("<", "<gv")
vmap(">", ">gv")
nmap("<leader>.", "<c-^>")
vmap(".", ":normal .<cr>")

nmap("<C-h>", "<Plug>WinMoveLeft")
nmap("<C-j>", "<Plug>WinMoveDown")
nmap("<C-k>", "<Plug>WinMoveUp")
nmap("<C-l>", "<Plug>WinMoveRight")

-- helpers for dealing with other people's code
nmap([[\t]], ":set ts=4 sts=4 sw=4 noet<cr>")
nmap([[\s]], ":set ts=4 sts=4 sw=4 et<cr>")

nmap("<leader>z", "<Plug>Zoom")

-- move line mappings
local opt_h = "˙"
local opt_j = "∆"
local opt_k = "˚"
local opt_l = "¬"

nnoremap(opt_h, ":cprev<cr>zz")
nnoremap(opt_l, ":cnext<cr>zz")

nnoremap(opt_j, ":m .+1<cr>==")
nnoremap(opt_k, ":m .-2<cr>==")
inoremap(opt_j, "<Esc>:m .+1<cr>==gi")
inoremap(opt_k, "<Esc>:m .-2<cr>==gi")
vnoremap(opt_j, ":m '>+1<cr>gv=gv")
vnoremap(opt_k, ":m '<-2<cr>gv=gv")

-- wrap visual selection in provided wrapper
vnoremap("$(", "<esc>`>a)<esc>`<i(<esc>") -- wrap in parentheses
vnoremap("$[", "<esc>`>a]<esc>`<i[<esc>") -- wrap in brackets
vnoremap("${", "<esc>`>a}<esc>`<i{<esc>") -- wrap in braces
vnoremap([[$']], [[<esc>`>a"<esc>`<i"<esc>]]) -- wrap in quotes
vnoremap("$'", "<esc>`>a'<esc>`<i'<esc>") -- wrap in single quotes
vnoremap([[$\]], "<esc>`>o*/<esc>`<O/*<esc>")
vnoremap([[$<]], "<esc>`>a><esc>`<i<<esc>")

-- toggle cursorline
nmap("<leader>i", ":set cursorline!<cr>")

-- scroll the viewport faster
nnoremap("<C-e>", "3<c-e>")
nnoremap("<C-y>", "3<c-y>")

-- moving up and down work as you would expect
nnoremap("j", 'v:count == 0 ? "gj" : "j"', { expr = true })
nnoremap("k", 'v:count == 0 ? "gk" : "k"', { expr = true })
nnoremap("^", 'v:count == 0 ? "g^" :  "^"', { expr = true })
nnoremap("$", 'v:count == 0 ? "g$" : "$"', { expr = true })

-- custom text objects
-- inner-line
xmap("il", ":<c-u>normal! g_v^<cr>")
omap("il", ":<c-u>normal! g_v^<cr>")
-- around line
vmap("al", ":<c-u>normal! $v0<cr>")
omap("al", ":<c-u>normal! $v0<cr>")

-- interesting word mappings
nmap("<leader>0", "<Plug>ClearInterestingWord")
nmap("<leader>1", "<Plug>HiInterestingWord1")
nmap("<leader>2", "<Plug>HiInterestingWord2")
nmap("<leader>3", "<Plug>HiInterestingWord3")
nmap("<leader>4", "<Plug>HiInterestingWord4")
nmap("<leader>5", "<Plug>HiInterestingWord5")
nmap("<leader>6", "<Plug>HiInterestingWord6")

-- open current buffer in a new tab
nmap("gTT", ":tab sb<cr>")

local theme = require("theme")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { import = "plugins" },
  { import = "plugins.extras.copilot" },
  { import = "plugins.extras.astro" },
}, { ui = { border = theme.border } })

cmd([[syntax on]])
cmd([[filetype plugin indent on]])

if require("utils").is_dark_mode() then
  vim.g.catppuccin_flavour = "mocha"
  vim.o.background = "dark"
else
  vim.g.catppuccin_flavour = "latte"
  vim.o.background = "light"
end

-- vim.command.colorscheme "catppuccin"
vim.cmd("colorscheme " .. current_theme)

-- set up custom symbols for LSP errors
local signs =
  { Error = icons.error, Warning = icons.warning, Warn = icons.warning, Hint = icons.hint, Info = icons.hint }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.diagnostic.config({ virtual_text = true, signs = true, update_in_insert = true, severity_sort = true })

-- make comments and HTML attributes italic
cmd([[highlight Comment cterm=italic term=italic gui=italic]])
cmd([[highlight htmlArg cterm=italic term=italic gui=italic]])
cmd([[highlight xmlAttrib cterm=italic term=italic gui=italic]])
cmd([[highlight Normal ctermbg=none]])
