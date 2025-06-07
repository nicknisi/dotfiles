---@type LazySpec
return {
    -- use mason-tool-installer for automatically installing Mason packages
    {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        -- overrides `require("mason-tool-installer").setup(...)`
        opts = {
            -- Make sure to use the names found in `:Mason`
            -- Lua packages is installed through community
            ensure_installed = {
                -- install language servers
                "clangd",
                "cmake-language-server",
                "bash-language-server",
                "verible",

                -- install formatters
                "clang-format",
                "cmakelang", --include:format, lint, etc
                "black",
                "prettier",
                "shfmt",

                -- install debuggers
                "debugpy",

                -- install any other package
                "shellcheck",
                "checkmake",
                "tree-sitter-cli",
            },
        },
    },
}
