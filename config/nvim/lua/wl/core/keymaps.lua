vim.g.mapleader = " "

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set("i", "jk", "<ESC>", opts)
keymap.set("i", "kj", "<ESC>", opts)

keymap.set("n", "<ESC>", ":nohl<CR>", opts)
keymap.set("n", "<leader>e", ":NvimTreeFindFileToggle<cr>", opts)
keymap.set("n", "<leader>r", ":NvimTreeFocus<cr>", opts)
keymap.set("n", "<leader>w", ":bd<cr>", opts)
keymap.set("n", "<leader>w<Left>", ":BufferLineCloseLeft<cr>", opts)
keymap.set("n", "<leader>w<Right>", ":BufferLineCloseRight<cr>", opts)
keymap.set("n", "<leader>q", "<C-w>q", opts)
keymap.set("n", "<A-,>", "<C-o>", opts)
keymap.set("n", "<A-.>", "<C-i>", opts)
keymap.set("n", "<A-o>", ":ClangdSwitchSourceHeader<cr>", opts)

keymap.set("i", "<A-h>", "<Left>", opts)
keymap.set("i", "<A-l>", "<Right>", opts)
keymap.set("i", "<A-k>", "<Up>", opts)
keymap.set("i", "<A-j>", "<Down>", opts)
keymap.set("n", "<C-s>", ":w<CR>", opts)

-- Visual --
-- Stay in indent mode
keymap.set("v", "<", "<gv", opts)
keymap.set("v", ">", ">gv", opts)

-- Move text up and down
keymap.set("v", "J", ":move '>+1<CR>gv-gv", opts)
keymap.set("v", "K", ":move '<-2<CR>gv-gv", opts)
keymap.set("v", "p", '"_dP', opts)
