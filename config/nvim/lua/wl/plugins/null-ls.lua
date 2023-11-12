return {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "jay-babu/mason-null-ls.nvim" },
    priority = 700,
    config = function()
        local null_ls = require("null-ls")
        local path = "--style=file:" .. vim.fn.stdpath("config") .. "/.clang-format"
        local sources = {
            null_ls.builtins.formatting.clang_format.with {
                extra_args = { path },
            },
            null_ls.builtins.formatting.stylua,
            null_ls.builtins.code_actions.gitsigns.with {
                config = {
                    filter_actions = function(title)
                        return title:lower():match("blame") == nil -- filter out blame actions
                    end,
                },
            },
            null_ls.builtins.formatting.cmake_format.with {
                extra_args = { "--enable-markup", "FALSE" }, --disable formatting on comments
            },
            -- null_ls.builtins.diagnostics.cmake_lint,
        }
        null_ls.setup {
            -- debug = true,
            sources = sources,
            --auto save when :w
            -- on_attach = function(current_client, bufnr)
            --     if current_client.supports_method("textDocument/formatting") then
            --         vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
            --         vim.api.nvim_create_autocmd("BufWritePre", {
            --             group = augroup,
            --             buffer = bufnr,
            --             callback = function()
            --                 vim.lsp.buf.format {
            --                     filter = function(client)
            --                         --  only use null-ls for formatting instead of lsp server
            --                         return client.name == "null-ls"
            --                     end,
            --                     bufnr = bufnr,
            --                 }
            --             end,
            --         })
            --     end
            -- end,
        }

        require("mason-null-ls").setup {
            ensure_installed = { "clang-format", "stylua", "cmake_format", "cmake_link" },
        }
    end,
}
