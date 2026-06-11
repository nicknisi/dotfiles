---@type LazySpec
return {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
        -- opts variable is the default configuration table for the setup function call
        local null_ls = require "null-ls"
        local path = "--style=file:" .. vim.fn.stdpath "config" .. "/.clang-format"

        -- Check supported formatters and linters
        -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/formatting
        -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics

        -- Only insert new sources, do not replace the existing ones
        -- (If you wish to replace, use `opts.sources = {}` instead of the `list_insert_unique` function)
        opts.sources = require("astrocore").list_insert_unique(opts.sources, {
            -- Set a formatter
            null_ls.builtins.formatting.clang_format.with {
                extra_args = { path },
            },
            null_ls.builtins.formatting.stylua,
            null_ls.builtins.code_actions.gitsigns.with {
                config = {
                    filter_actions = function(title)
                        return title:lower():match "blame" == nil -- filter out blame actions
                    end,
                },
            },
            null_ls.builtins.formatting.cmake_format.with {
                extra_args = { "--enable-markup", "FALSE" }, --disable formatting on comments
            },
            null_ls.builtins.formatting.black,
            null_ls.builtins.formatting.prettier, --[[ todo:https://prettier.io/docs/en/configuration.html ]]
            null_ls.builtins.formatting.verible_verilog_format,
            -- null_ls.builtins.diagnostics.checkmake,
        })
        -- opts.debug = true
    end,
}
