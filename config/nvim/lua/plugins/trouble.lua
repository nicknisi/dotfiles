require("trouble").setup()
local nnoremap = require("utils").nnoremap

-- trouble keymappings
nnoremap("<leader>xx", "<cmd>TroubleToggle<cr>")
nnoremap("<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>")
nnoremap("<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>")
nnoremap("<leader>xq", "<cmd>TroubleToggle quickfix<cr>")
nnoremap("<leader>xl", "<cmd>TroubleToggle loclist<cr>")
-- nnoremap("gR", "<cmd>TroubleToggle lsp_references<cr>")
