---@type LazySpec
return {
    "nvim-treesitter/nvim-treesitter",
    opts = {
        ensure_installed = {
            "cpp",
            "c",
            "python",
            "lua",
            "cmake",
            "json",
            "vim",
            "vimdoc",
            "query",
            "markdown",
            "markdown_inline",
            "regex",
            "bash",
            "verilog",
        },
    },
}
