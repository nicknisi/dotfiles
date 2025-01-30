local utils = require("nisi.utils")
local nmap = utils.nmap
local vmap = utils.vmap
local imap = utils.imap
local xmap = utils.xmap
local omap = utils.omap
local nnoremap = utils.nnoremap
local inoremap = utils.inoremap
local vnoremap = utils.vnoremap
local termcodes = utils.termcodes

vim.g.mapleader = ","

local version = vim.version()
if version.major == 0 and version.minor < 10 then
  -- this is no longer needed in nightly (0.10)
  vim.opt.pastetoggle = "<leader>v"
end

if not vim.g.vscode then
  -- create a completion_nvim table on _G which is visible via
  -- v:lua from vimscript
  _G.completion_nvim = {}

  function _G.completion_nvim.smart_pumvisible(vis_seq, not_vis_seq)
    if vim.fn.pumvisible() == 1 then
      return termcodes(vis_seq)
    else
      return termcodes(not_vis_seq)
    end
  end

  -- navigate menus with ctrl + j/k
  inoremap("<C-j>", [[v:lua.completion_nvim.smart_pumvisible('<C-n>', '<C-j>')]], { expr = true })
  inoremap("<C-k>", [[v:lua.completion_nvim.smart_pumvisible('<C-p>', '<C-k>')]], { expr = true })
end

nnoremap("Q", "<nop>") -- don't accidentally go into Ex mode
imap("jk", "<Esc>", { desc = "Exit insert mode" })

-- save file keybindings
nmap("<leader>,", ":silent w<cr>", { desc = "Save File" })
-- ctrl-s bindings
nmap("<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
-- cmd-s bindings
nmap("<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
nmap("<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

nmap("<space>", ":silent set hlsearch! hlsearch?<cr>", { desc = "Toggle search results" })
nmap("<leader>l", ":set list!<cr>", { desc = "Toggle invisible characters" })
nmap("<leader>.", "<c-^>", { desc = "Go to last buffer" })
nmap("<leader>z", "<Plug>Zoom", { desc = "Toggle zoom" })

-- helpers for dealing with other people's code
nmap([[\t]], ":set ts=4 sts=4 sw=4 noet<cr>", { desc = "Set tabs" })
nmap([[\s]], ":set ts=4 sts=4 sw=4 et<cr>", { desc = "Set spaces" })

-- indent outdent while in visual mode
vmap("<", "<gv")
vmap(">", ">gv")

vmap(".", ":normal .<cr>") -- run `.` command in visual mode

-- Move between panes or create new panes
nmap("<C-h>", "<Plug>WinMoveLeft")
nmap("<C-j>", "<Plug>WinMoveDown")
nmap("<C-k>", "<Plug>WinMoveUp")
nmap("<C-l>", "<Plug>WinMoveRight")

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

-- copy and normalize text
vmap("<leader>y", utils.copy_normalized_block, { desc = "Copy and normalized" })

-- open current buffer in a new tab
nmap("gTT", ":tab sb<cr>", { desc = "Open current buffer in a new tab" })
