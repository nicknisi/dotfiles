---@type LazySpec
return {
    "nvimtools/none-ls.nvim",
    opts = function(_, config)
        -- config variable is the default configuration table for the setup function call
        local null_ls = require "null-ls"
        local path = "--style=file:" .. vim.fn.stdpath "config" .. "/.clang-format"
        local sources = {
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
        }

        config.sources = sources
        -- config.debug = true
        return config -- return final config table
    end,
}
