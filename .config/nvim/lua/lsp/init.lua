-- vim.lsp.set_log_level("debug")
require('lsp.gopls')
require('lsp.lua')
require('lsp.efm')
require('lsp.tsserver')
require('lsp.python')

require'lspconfig'.yamlls.setup {
    on_attach = function(client, bufnr)
        require('lsp.attach').on_attach(client, bufnr)
    end,
    capabilities = require('lsp.attach').capabilities
}

require'lspconfig'.clangd.setup {
    on_attach = function(client, bufnr)
        require('lsp.attach').on_attach(client, bufnr)
    end,
    capabilities = require('lsp.attach').capabilities
}
