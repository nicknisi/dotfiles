local nvim_lsp = require('lspconfig')

nvim_lsp.gopls.setup {
    on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        require('lsp/attach').on_attach(client, bufnr)
    end,
    capabilities = require('lsp/attach').capabilities,
    init_options = {usePlaceholders = true, linksInHover = false, allowModfileModifications = true}
}
