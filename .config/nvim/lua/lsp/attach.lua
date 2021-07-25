local M = {}

M.on_attach = function(_, bufnr)
    local function buf_map(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    buf_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    local opts = {noremap = true, silent = true}

    buf_map('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_map('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_map('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_map('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_map('n', 'gy', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_map('n', '<space>en', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    buf_map('n', '<space>o',
            '<cmd>lua vim.lsp.buf.formatting_sync(nil, 10000)<CR>', opts)
    buf_map('n', '[d',
            '<cmd>lua vim.lsp.diagnostic.goto_prev({ wrap = false })<CR>', opts)
    buf_map('n', ']d',
            '<cmd>lua vim.lsp.diagnostic.goto_next({ wrap = false })<CR>', opts)

    require'lsp_signature'.on_attach({
        floating_window = false,
        hint_enable = true,
        hint_prefix = '',
        hint_scheme = 'String',
        use_lspsaga = false,
        hi_parameter = 'Search',
        extra_trigger_chars = {'(', ','}
    })
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities.textDocument.completion.completionItem.snippetSupport = true

return M
