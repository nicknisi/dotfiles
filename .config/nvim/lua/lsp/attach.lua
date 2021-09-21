local M = {}

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "single" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "single" })

M.on_attach = function(_, bufnr)
    local function buf_map(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end
    local opts = { noremap = true, silent = true }

    buf_option("omnifunc", "v:lua.vim.lsp.omnifunc")

    buf_map("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    buf_map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    buf_map("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    buf_map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    buf_map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    buf_map("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    buf_map("n", "<leader>en", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    buf_map("n", "<leader>f", "<cmd>lua vim.lsp.buf.formatting_seq_sync(nil, 1000)<CR>", opts)
    buf_map(
        "n",
        "[d",
        '<cmd>lua vim.lsp.diagnostic.goto_prev({ wrap = false, popup_opts = { border = "single" } })<CR>',
        opts
    )
    buf_map(
        "n",
        "]d",
        '<cmd>lua vim.lsp.diagnostic.goto_next({ wrap = false, popup_opts = { border = "single" } })<CR>',
        opts
    )
    buf_map("n", "ga", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
end

M.capabilities = require("cmp_nvim_lsp").update_capabilities(vim.lsp.protocol.make_client_capabilities())

return M
