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
                        },
                    },
                },
            },
        },
    },

    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
            { "zbirenbaum/copilot.lua" },
            { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
        },
        opts = {
            model = "claude-3.7-sonnet",
            -- See Configuration section for options
            question_header = "  ", -- Header to use for user questions
            answer_header = "   ", -- Header to use for AI answers
            error_header = "  ", -- Header to use for errors
        },

        specs = {
            {
                "AstroNvim/astroui",
                optional = true,
                opts = {
                    highlights = {
                        init = { -- this table overrides highlights in all themes
                            CopilotChatHeader = { fg = "#56b6c2" }, -- Change the color of the question header
                            CopilotChatSeparator = { fg = "#56b6c2" }, -- Change the color of the separator
                        },
                    },
                },
            },

            {
                "saghen/blink.cmp",
                optional = true,
                ---@module 'blink.cmp'
                ---@type blink.cmp.Config
                opts = {
                    sources = {
                        providers = {
                            path = {
                                -- Path sources triggered by "/" interfere with CopilotChat commands
                                enabled = function() return vim.bo.filetype ~= "copilot-chat" end,
                            },
                        },
                    },
                },
            },

            {
                "AstroNvim/astrocore",
                optional = true,
                opts = {
                    mappings = {
                        n = {
                            ["<Leader>a"] = {
                                desc = "AiChat",
                            },
                            ["<Leader>aa"] = {
                                "<cmd>CopilotChat<cr>",
                            },
                            ["<Leader>ae"] = {
                                "<cmd>CopilotChatToggle<cr>",
                            },
                        },
                        v = {
                            ["<Leader>a"] = {
                                desc = "AiChat",
                            },
                            ["<Leader>aa"] = {
                                "<cmd>CopilotChat<cr>",
                            },
                            ["<Leader>ae"] = {
                                "<cmd>CopilotChatToggle<cr>",
                            },
                        },
                    },
                },
            },
        },
    },
}
