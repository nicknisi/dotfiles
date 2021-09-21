vim.g.indent_blankline_char_highlight = "LineNr"
vim.g.indent_blankline_strict_tabs = true
vim.g.indent_blankline_show_current_context = true
vim.g.indent_blankline_context_patterns = {
    "class",
    "function",
    "method",
    "^if",
    "while",
    "for",
    "with",
    "func_literal",
    "block",
    "try",
    "except",
    "argument_list",
    "object",
    "dictionary",
}

require("indent_blankline").setup({
    char = "▏",
    filetype_exclude = {
        "help",
        "terminal",
        "dashboard",
        "packer",
        "lspinfo",
        "TelescopePrompt",
        "TelescopeResults",
    },
    buftype_exclude = { "terminal", "qf", "terminal", "packer" },
    show_trailing_blankline_indent = false,
    show_first_indent_level = false,
})
