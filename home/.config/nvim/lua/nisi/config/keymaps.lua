vim.g.mapleader = ","

vim.keymap.set("n", "Q", "<nop>", { desc = "Disable Ex mode" })
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- save file keybindings
vim.keymap.set("n", "<leader>,", "<cmd>silent w<cr>", { desc = "Save File" })
-- ctrl-s bindings
vim.keymap.set({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })
-- cmd-s bindings
vim.keymap.set({ "n", "i", "v" }, "<D-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

vim.keymap.set("n", "<space>", "<cmd>silent set hlsearch! hlsearch?<cr>", { desc = "Toggle search results" })
vim.keymap.set("n", "<leader>l", "<cmd>set list!<cr>", { desc = "Toggle invisible characters" })
vim.keymap.set("n", "<leader>.", "<c-^>", { desc = "Go to last buffer" })
vim.keymap.set("n", "<leader>z", "<Plug>Zoom", { desc = "Toggle zoom", remap = true })

-- helpers for dealing with other people's code
vim.keymap.set("n", "\\t", "<cmd>set ts=4 sts=4 sw=4 noet<cr>", { desc = "Set tabs" })
vim.keymap.set("n", "\\s", "<cmd>set ts=4 sts=4 sw=4 et<cr>", { desc = "Set spaces" })

-- indent outdent while in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

vim.keymap.set("v", ".", ":normal .<cr>", { desc = "Repeat last command" })

-- Move between panes or create new panes
vim.keymap.set("n", "<C-h>", "<Plug>WinMoveLeft", { desc = "Move to left window", remap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<Plug>WinMoveDown", { desc = "Move to window below", remap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<Plug>WinMoveUp", { desc = "Move to window above", remap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<Plug>WinMoveRight", { desc = "Move to right window", remap = true, silent = true })

-- Quickfix navigation using vim-unimpaired style
vim.keymap.set("n", "[q", "<cmd>cprev<cr>zz", { desc = "Previous quickfix item" })
vim.keymap.set("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })

-- Move lines with simple arrow keys (can be held down)
vim.keymap.set("n", "<Up>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
vim.keymap.set("n", "<Down>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
vim.keymap.set("v", "<Up>", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
vim.keymap.set("v", "<Down>", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })

-- If you want to keep J/K in visual mode for moving (doesn't conflict there)
vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })

-- wrap visual selection in provided wrapper
vim.keymap.set("v", "$(", "<esc>`>a)<esc>`<i(<esc>", { desc = "Wrap in parentheses" })
vim.keymap.set("v", "$[", "<esc>`>a]<esc>`<i[<esc>", { desc = "Wrap in brackets" })
vim.keymap.set("v", "${", "<esc>`>a}<esc>`<i{<esc>", { desc = "Wrap in braces" })
vim.keymap.set("v", "$'", "<esc>`>a'<esc>`<i'<esc>", { desc = "Wrap in single quotes" })
vim.keymap.set("v", '$"', '<esc>`>a"<esc>`<i"<esc>', { desc = "Wrap in double quotes" })
vim.keymap.set("v", "$\\", "<esc>`>o*/<esc>`<O/*<esc>", { desc = "Wrap in C-style comment" })
vim.keymap.set("v", "$<", "<esc>`>a><esc>`<i<<esc>", { desc = "Wrap in angle brackets" })

-- toggle cursorline
vim.keymap.set("n", "<leader>i", "<cmd>set cursorline!<cr>", { desc = "Toggle cursor line" })

-- scroll the viewport faster
vim.keymap.set("n", "<C-e>", "3<c-e>", { desc = "Scroll down faster" })
vim.keymap.set("n", "<C-y>", "3<c-y>", { desc = "Scroll up faster" })

-- moving up and down work as you would expect
vim.keymap.set("n", "j", 'v:count == 0 ? "gj" : "j"', { expr = true, desc = "Move down (wrap friendly)" })
vim.keymap.set("n", "k", 'v:count == 0 ? "gk" : "k"', { expr = true, desc = "Move up (wrap friendly)" })
vim.keymap.set("n", "^", 'v:count == 0 ? "g^" :  "^"', { expr = true, desc = "Start of line (wrap friendly)" })
vim.keymap.set("n", "$", 'v:count == 0 ? "g$" : "$"', { expr = true, desc = "End of line (wrap friendly)" })

-- custom text objects
-- inner-line
vim.keymap.set("x", "il", ":<c-u>normal! g_v^<cr>", { desc = "Inner line text object" })
vim.keymap.set("o", "il", ":<c-u>normal! g_v^<cr>", { desc = "Inner line text object" })
-- around line
vim.keymap.set("v", "al", ":<c-u>normal! $v0<cr>", { desc = "Around line text object" })
vim.keymap.set("o", "al", ":<c-u>normal! $v0<cr>", { desc = "Around line text object" })

-- interesting word mappings
vim.keymap.set("n", "<leader>0", "<Plug>ClearInterestingWord", { desc = "Clear interesting word", remap = true })
vim.keymap.set("n", "<leader>1", "<Plug>HiInterestingWord1", { desc = "Highlight interesting word 1", remap = true })
vim.keymap.set("n", "<leader>2", "<Plug>HiInterestingWord2", { desc = "Highlight interesting word 2", remap = true })
vim.keymap.set("n", "<leader>3", "<Plug>HiInterestingWord3", { desc = "Highlight interesting word 3", remap = true })
vim.keymap.set("n", "<leader>4", "<Plug>HiInterestingWord4", { desc = "Highlight interesting word 4", remap = true })
vim.keymap.set("n", "<leader>5", "<Plug>HiInterestingWord5", { desc = "Highlight interesting word 5", remap = true })
vim.keymap.set("n", "<leader>6", "<Plug>HiInterestingWord6", { desc = "Highlight interesting word 6", remap = true })

-- copy and normalize text
vim.keymap.set("v", "<leader>y", function()
  local utils = require("nisi.utils")
  utils.copy_normalized_block()
end, { desc = "Copy and normalize" })

-- open current buffer in a new tab
vim.keymap.set("n", "gTT", "<cmd>tab sb<cr>", { desc = "Open current buffer in a new tab" })
