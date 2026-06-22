---@type LazySpec
return {
    {
        "mason-org/mason.nvim",
        opts = {
            PATH = "append",
        },
    },
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
                "neocmakelsp",
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
            },
        },
    },
}
