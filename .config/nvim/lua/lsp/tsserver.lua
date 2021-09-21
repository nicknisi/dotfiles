local nvim_lsp = require("lspconfig")

nvim_lsp.tsserver.setup({
    root_dir = nvim_lsp.util.root_pattern("tsconfig.json", "jsconfig.json", ".git"),
    on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        require("lsp/attach").on_attach(client, bufnr)
    end,
    capabilities = require("lsp/attach").capabilities,
})
