return {
    {
        "folke/which-key.nvim",
        config = function()
            vim.o.timeout = true
            vim.o.timeoutlen = 600
            require("which-key").setup {
                -- your configuration comes here
                -- or leave it empty to use the default settings
                -- refer to the configuration section below
            }
            local wk = require("which-key")
            wk.register {
                ["<leader>"] = {
                    g = {
                        name = "Lsp",
                        h = "lsp finder",
                        d = "goto definition",
                        D = "peek definition",
                        c = "code action",
                        r = "rename",
                        R = "rename gobally",
                    },
                    q = {
                        name = "quit window",
                    },
                    cl = {
                        name = "clear highlight",
                    },
                    f = {
                        name = "Telescope",
                        a = "format",
                        f = "find files",
                        b = "find buffers",
                        d = "find diagnostics",
                        g = "live grep",
                        h = "find help",
                        r = "find register",
                        u = "find document symbols",
                        i = "find workspace symbols",
                    },
                },
            }
        end,
    },
}
