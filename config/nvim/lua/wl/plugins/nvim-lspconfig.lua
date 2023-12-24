return {
    {
        "williamboman/mason.nvim",
        config = function() end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "neovim/nvim-lspconfig",
        },
        config = function() end,
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = "hrsh7th/cmp-nvim-lsp",
        config = function()
            --keep order
            require("mason").setup()
            require("mason-lspconfig").setup {
                ensure_installed = { "clangd", "cmake", "lua_ls", "pyright" },
            }

            local opts = { noremap = true, silent = true }
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

            local lsp_formatting = function(bufnr)
                local visual_mode = vim.fn.mode()
                local region = nil

                if visual_mode == "v" or visual_mode == "V" then
                    local start_pos = vim.fn.getpos("'<")
                    local end_pos = vim.fn.getpos("'>")
                    local start_line = start_pos[2]
                    local start_col = start_pos[3]
                    local end_line = end_pos[2]
                    local end_col = end_pos[3]
                    region = {
                        ["start"] = { start_line, start_col },
                        ["end"] = { end_line, end_col },
                    }
                end

                vim.lsp.buf.format {
                    filter = function(client)
                        -- apply whatever logic you want (in this example, we'll only use null-ls)
                        return client.name == "null-ls"
                    end,
                    bufnr = bufnr,
                    range = region,
                }
            end

            vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>")
            vim.keymap.set({ "n", "v" }, "<space>fm", function()
                lsp_formatting()
            end, {noremap = true, silent = true})

            -- Use an on_attach function to only map the following keys
            -- after the language server attaches to the current buffer
            local on_attach = function(client, bufnr)
                vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

                -- Mappings.
                -- See `:help vim.lsp.*` for documentation on any of the below functions
                local bufopts = { noremap = true, silent = true, buffer = bufnr }
                vim.keymap.set("n", "gh", "<cmd>Lspsaga finder<CR>")
                vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>")
                vim.keymap.set("n", "gD", "<cmd>Lspsaga peek_definition<CR>")
                vim.keymap.set("n", "sw", "<cmd>Lspsaga show_buf_diagnostics<CR>")
                vim.keymap.set("n", "gr", "<cmd>Lspsaga rename<CR>")
                vim.keymap.set("n", "gR", "<cmd>Lspsaga rename ++project<CR>")
                -- vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
                vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>")
                vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
                vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
                vim.keymap.set("n", "<space>wl", function()
                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end, bufopts)
            end

            local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = "󰋽 " }
            for type, icon in pairs(signs) do
                local hl = "DiagnosticSign" .. type
                vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
            end

            -- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            capabilities.offsetEncoding = { "utf-16" }
            require("lspconfig")["clangd"].setup {
                on_attach = on_attach,
                capabilities = capabilities,
                cmd = {
                    "clangd",
                    "--query-driver=/home/linuxbrew/.linuxbrew/bin/gcc-13,/usr/bin/gcc",
                    "--limit-references=0",
                    "--limit-results=1000",
                    "--pch-storage=memory",
                    -- "--log=verbose",
                },
            }

            -- settings for lua-language-server can be found on https://github.com/LuaLS/lua-language-server/wiki/Settings .
            require("lspconfig")["lua_ls"].setup {
                on_attach = on_attach,
                settings = {
                    Lua = {
                        runtime = {
                            -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                            version = "LuaJIT",
                        },
                        diagnostics = {
                            -- Get the language server to recognize the `vim` global
                            globals = { "vim" },
                        },
                        -- workspace = {
                        --   -- Make the server aware of Neovim runtime files,
                        --   -- see also https://github.com/LuaLS/lua-language-server/wiki/Libraries#link-to-workspace .
                        --   -- Lua-dev.nvim also has similar settings for lua ls, https://github.com/folke/neodev.nvim/blob/main/lua/neodev/luals.lua .
                        --   library = {
                        --     fn.stdpath("data") .. "/site/pack/packer/opt/emmylua-nvim",
                        --     fn.stdpath("config"),
                        --   },
                        --   maxPreload = 2000,
                        --   preloadFileSize = 50000,
                        -- },
                    },
                },
                capabilities = capabilities,
            }

            require("lspconfig").cmake.setup {
                on_attach = on_attach,
                capabilities = capabilities,
            }
            require("lspconfig").pyright.setup {
                on_attach = on_attach,
                capabilities = capabilities,
            }
        end,
    },
    {
        "glepnir/lspsaga.nvim",
        event = "BufRead",
        config = function()
            vim.api.nvim_set_hl(0, "SagaNormal", { link = "Normal", default = true })
            require("lspsaga").setup {
                lightbulb = {
                    enable = true,
                    sign = false,
                    sign_priority = 40,
                    virtual_text = true,
                    debounce = 500,
                },
            }
        end,
        dependencies = {
            { "nvim-tree/nvim-web-devicons" },
            --Please make sure you install markdown and markdown_inline parser
            { "nvim-treesitter/nvim-treesitter" },
        },
    },
}
