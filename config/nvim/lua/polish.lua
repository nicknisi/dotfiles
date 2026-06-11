-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

local opts = { noremap = true, silent = true }
vim.keymap.set("v", "J", ":move '>+1<CR>gv-gv", opts)
vim.keymap.set("v", "K", ":move '<-2<CR>gv-gv", opts)
vim.keymap.set("v", "p", '"_dP', opts)
vim.keymap.set("n", "<A-o>", ":ClangdSwitchSourceHeader<cr>", opts)
