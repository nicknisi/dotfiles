local function filter_ai_trigger()
    local filename = vim.fn.expand "%:t"
    if filename:match "%.localrc" or filename:match "%.env" then return false end
    return true
end

return {
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        build = ":Copilot auth",
        event = "BufReadPost",
        opts = {
            suggestion = { enabled = false },
            panel = { enabled = false },
        },
        specs = {
            "saghen/blink.cmp",
            optional = true,
            dependencies = { "giuxtaposition/blink-cmp-copilot" },
            opts = {
                sources = {
                    default = { "copilot" },
                    providers = {
                        copilot = {
                            name = "copilot",
                            module = "blink-cmp-copilot",
                            score_offset = 100,
                            async = true,
                            enabled = filter_ai_trigger,
                        },
                    },
                },
            },
        },
    },

    {
        "supermaven-inc/supermaven-nvim",
        opts = {
            disable_inline_completion = true, -- disables inline completion for use with cmp
            disable_keymaps = true, -- disables built in keymaps for more manual control
            condition = filter_ai_trigger,
        },
        specs = {
            "saghen/blink.cmp",
            optional = true,
            dependencies = { "huijiro/blink-cmp-supermaven" },
            opts = {
                sources = {
                    default = { "supermaven" },
                    providers = {
                        supermaven = {
                            name = "supermaven",
                            module = "blink-cmp-supermaven",
                            score_offset = 99,
                            async = true,
                            enabled = filter_ai_trigger,
                        },
                    },
                },
            },
        },
    },

    {
        "Exafunction/windsurf.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        config = function()
            require("codeium").setup {
                enable_chat = false,
            }
        end,
        specs = {
            "saghen/blink.cmp",
            optional = true,
            opts = {
                sources = {
                    default = { "codeium" },
                    providers = {
                        codeium = {
                            name = "Codeium",
                            module = "codeium.blink",
                            max_items = 3,
                            async = true,
                            enabled = filter_ai_trigger,
                        },
                    },
                },
            },
        },
    },

    -- {
    --     "milanglacier/minuet-ai.nvim",
    --     enabled = false,
    --     config = function()
    --         require("minuet").setup {
    --             n_completions = 1,
    --             provider = "codestral",
    --             provider_options = {
    --                 codestral = {
    --                     optional = {
    --                         temperature = 0.0,
    --                         max_tokens = 256,
    --                         stop = { "\n\n" },
    --                     },
    --                 },
    --
    --                 openai_fim_compatible = {
    --                     api_key = "DEEPSEEK_API_KEY",
    --                     name = "deepseek",
    --                     optional = {
    --                         temperature = 0.0,
    --                         max_tokens = 256,
    --                     },
    --                 },
    --
    --                 openai_compatible = {
    --                     end_point = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    --                     api_key = "DASHSCOPE_API_KEY",
    --                     name = "qwen",
    --                     model = "qwen3-coder-flash",
    --                     optional = {
    --                         max_tokens = 256,
    --                         temperature = 0.0,
    --                     },
    --                 },
    --             },
    --         }
    --     end,
    --     specs = {
    --         {
    --             "saghen/blink.cmp",
    --             optional = true,
    --             opts = {
    --                 sources = {
    --                     default = { "minuet" },
    --                     providers = {
    --                         minuet = {
    --                             name = "minuet",
    --                             module = "minuet.blink",
    --                             async = true,
    --                             timeout_ms = 3000,
    --                             score_offset = 50, -- Gives minuet higher priority among suggestions
    --                             enabled = filter_ai_trigger,
    --                         },
    --                     },
    --                 },
    --             },
    --         },
    --     },
    -- },
    {
        "NickvanDyke/opencode.nvim",
        dependencies = {
            -- Recommended for `ask()` and `select()`.
            -- Required for `snacks` provider.
            ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
            { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
        },
        config = function()
            ---@type opencode.Opts
            vim.g.opencode_opts = {
                -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition" on the type or field.
                provider = {
                    enabled = "snacks",
                },
            }

            -- Required for `opts.events.reload`.
            vim.o.autoread = true

            -- Recommended/example keymaps.
            vim.keymap.set(
                { "n", "x" },
                "<C-a>",
                function() require("opencode").ask("@this: ", { submit = true }) end,
                { desc = "Ask opencode…" }
            )
            vim.keymap.set(
                { "n", "x" },
                "<C-x>",
                function() require("opencode").select() end,
                { desc = "Execute opencode action…" }
            )
            vim.keymap.set(
                { "n", "t" },
                "<leader>o",
                function() require("opencode").toggle() end,
                { desc = "Toggle opencode" }
            )

            vim.keymap.set(
                { "n", "x" },
                "go",
                function() return require("opencode").operator "@this " end,
                { desc = "Add range to opencode", expr = true }
            )
            vim.keymap.set(
                "n",
                "goo",
                function() return require("opencode").operator "@this " .. "_" end,
                { desc = "Add line to opencode", expr = true }
            )
        end,
    },
}
