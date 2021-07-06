local prettier = {
    formatCommand = 'prettier --stdin --stdin-filepath ${INPUT}',
    formatStdin = true
}

local eslint_d = {
    lintCommand = 'eslint_d -f unix --stdin --stdin-filename ${INPUT}',
    lintStdin = true,
    lintFormats = {'%f:%l:%c: %m'},
    lintIgnoreExitCode = true,
    formatCommand = 'eslint_d --fix-to-stdout --stdin --stdin-filename=${INPUT}',
    formatStdin = true
}

require'lspconfig'.efm.setup {
    init_options = {documentFormatting = true},
    filetypes = {
        'javascript', 'typescript', 'typescriptreact', 'javascriptreact', 'lua'
    },
    settings = {
        rootMarkers = {'.git/'},
        languages = {
            lua = {
                {
                    formatCommand = 'lua-format -i --double-quote-to-single-quote --no-keep-simple-function-one-line',
                    formatStdin = true
                }
            },
            typescript = {prettier, eslint_d},
            javascript = {prettier, eslint_d},
            typescriptreact = {prettier, eslint_d},
            javascriptreact = {prettier, eslint_d}
        }
    }
}

