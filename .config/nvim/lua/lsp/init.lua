-- vim.lsp.set_log_level("debug")
require("lsp.gopls")
require("lsp.sumneko")
require("lsp.tsserver")
require("lsp.pyright")

require("lspconfig").yamlls.setup({
    on_attach = require("lsp.attach").on_attach,
    capabilities = require("lsp.attach").capabilities,
})

require("lspconfig").clangd.setup({
    on_attach = require("lsp.attach").on_attach,
    capabilities = require("lsp.attach").capabilities,
})

require("lspconfig").rust_analyzer.setup({
    on_attach = require("lsp.attach").on_attach,
    capabilities = require("lsp.attach").capabilities,
})
