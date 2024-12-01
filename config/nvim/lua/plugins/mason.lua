---@type LazySpec
return {
    -- use mason-lspconfig to configure LSP installations
    {
        "williamboman/mason-lspconfig.nvim",
        -- overrides `require("mason-lspconfig").setup(...)`
        opts = function(_, opts)
            -- add more things to the ensure_installed table protecting against community packs modifying it
            opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
                "lua_ls",
                "clangd",
                "cmake",
                "lua_ls",
                "bashls",
            })
        end,
    },
    -- use mason-null-ls to configure Formatters/Linter installation for null-ls sources
    {
        "jay-babu/mason-null-ls.nvim",
        -- overrides `require("mason-null-ls").setup(...)`
        opts = function(_, opts)
            -- add more things to the ensure_installed table protecting against community packs modifying it
            opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
                "stylua",
                "clang-format",
                "stylua",
                "cmake_format",
                "black",
                "prettier",
                "shellcheck",
                "shfmt",
                "verible",
                -- "checkmake",
            })
        end,
    },
    {
        "jay-babu/mason-nvim-dap.nvim",
        -- overrides `require("mason-nvim-dap").setup(...)`
        opts = function(_, opts)
            -- add more things to the ensure_installed table protecting against community packs modifying it
            opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
                "python",
                -- add more arguments for adding more debuggers
            })
        end,
    },
}
