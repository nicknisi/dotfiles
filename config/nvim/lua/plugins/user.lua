-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {
    {
        "folke/snacks.nvim",
        optional = true,
        opts = {
            dashboard = {
                preset = {
                    header = table.concat({
                        " █████  ███████ ████████ ██████   ██████ ",
                        "██   ██ ██         ██    ██   ██ ██    ██",
                        "███████ ███████    ██    ██████  ██    ██",
                        "██   ██      ██    ██    ██   ██ ██    ██",
                        "██   ██ ███████    ██    ██   ██  ██████ ",
                        "",
                        "███    ██ ██    ██ ██ ███    ███",
                        "████   ██ ██    ██ ██ ████  ████",
                        "██ ██  ██ ██    ██ ██ ██ ████ ██",
                        "██  ██ ██  ██  ██  ██ ██  ██  ██",
                        "██   ████   ████   ██ ██      ██",
                    }, "\n"),
                },
            },

            notifier = {
                -- used for noice.nvim for notify view
                timeout = 2500,
                top_down = false,
            },

            picker = {
                -- layout = {preset = "vscode"},
                win = {
                    -- internal keymaps
                    input = {
                        keys = {
                            ["<c-v>"] = false,
                            ["<c-q>"] = { "edit_vsplit", mode = { "i", "n" } },
                        },
                    },

                    -- internal keymaps
                    list = {
                        keys = {
                            ["<c-v>"] = false,
                            ["<c-q>"] = "edit_vsplit",
                        },
                    },
                },
            },

            terminal = {
                win = {
                    style = "terminal",
                },
            },
        },
        keys = {
            {
                "<leader>gg",
                function() require("snacks").lazygit { cwd = vim.fn.expand "%:p:h" } end,
                desc = "Lazygit (Current File Dir)",
            },
        },
    },

    -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
    {
        "L3MON4D3/LuaSnip",
        config = function(plugin, opts)
            require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
            -- add more custom luasnip configuration such as filetype extend or custom snippets
            local luasnip = require "luasnip"
            luasnip.filetype_extend("javascript", { "javascriptreact" })
            luasnip.filetype_extend("c", { "cdoc" })
            luasnip.filetype_extend("cpp", { "c" })

            -- load friendly-snippets, url:https://github.com/rafamadriz/friendly-snippets/tree/main
            -- load custom snippets
            -- mind that package.json need to be updated
            require("luasnip.loaders.from_vscode").lazy_load { paths = { "./vscode_snippets" } }
        end,
    },

    {
        "windwp/nvim-autopairs",
        config = function(plugin, opts)
            require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
            -- add more custom autopairs configuration such as custom rules
            local npairs = require "nvim-autopairs"
            local Rule = require "nvim-autopairs.rule"
            local cond = require "nvim-autopairs.conds"
            npairs.add_rules(
                {
                    Rule("$", "$", { "tex", "latex" })
                        -- don't add a pair if the next character is %
                        :with_pair(
                            cond.not_after_regex "%%"
                        )
                        -- don't add a pair if  the previous character is xxx
                        :with_pair(
                            cond.not_before_regex("xxx", 3)
                        )
                        -- don't move right when repeat character
                        :with_move(cond.none())
                        -- don't delete if the next character is xx
                        :with_del(
                            cond.not_after_regex "xx"
                        )
                        -- disable adding a newline when you press <cr>
                        :with_cr(cond.none()),
                },
                -- disable for .vim files, but it work for another filetypes
                Rule("a", "a", "-vim")
            )
        end,
    },
    {
        "olimorris/onedarkpro.nvim",
        opts = {
            options = {
                cursorline = true,
                highlight_inactive_windows = false,
                -- terminal_colors = false,
            },
        },
    },

    {
        "AstroNvim/astrotheme",
        lazy = false,
    },

    {
        "folke/noice.nvim",
        opts = {
            presets = {
                bottom_search = false, -- use a classic bottom cmdline for search
                command_palette = true, -- position the cmdline and popupmenu together
                long_message_to_split = true, -- long messages will be sent to a split
                inc_rename = false, -- enables an input dialog for inc-rename.nvim
            },

            messages = { view_search = false },

            popupmenu = { enabled = false },

            lsp = {
                hover = {
                    enabled = false,
                },
                signature = {
                    enabled = false,
                },
            },

            routes = {
                {
                    -- skip lsp progress from null-ls server
                    filter = {
                        event = "lsp",
                        kind = "progress",
                        cond = function(message)
                            local client = vim.tbl_get(message.opts, "progress", "client")
                            return client == "null-ls"
                        end,
                    },
                    opts = { skip = true },
                },

                {
                    -- Add shell output and error notification
                    filter = {
                        event = "msg_show",
                        kind = { "shell_out", "shell_err" },
                    },
                    view = "notify",
                    opts = { title = "Shell" },
                },
            },
        },
    },

    {
        "folke/which-key.nvim",
        opts = {
            delay = 800,
        },
    },
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        opts = {
            modes = {
                char = {
                    jump_labels = true,
                },
            },
            label = {
                uppercase = false,
            },
        },
    },

    {
        "nvimdev/lspsaga.nvim",
        -- enabled = false,
        opts = {
            code_action = {
                show_server_name = true,
            },
        },
    },

    {
        "akinsho/toggleterm.nvim",
        lazy = false,
        opts = function(plugin, opts)
            opts.size = function(term)
                if term.direction == "vertical" then return 80 end
                return 20 -- default size for horizontal and float
            end

            opts.on_create = function(t)
                vim.opt_local.foldcolumn = "0"
                vim.opt_local.signcolumn = "no"
            end

            -- change direction for terminal
            local direction = "float"
            local function term_toggle(dir)
                direction = dir
                vim.cmd(vim.v.count .. "ToggleTerm" .. " direction=" .. direction)
            end
            vim.keymap.set(
                "n",
                "<Leader>tv",
                function() term_toggle "vertical" end,
                { noremap = true, silent = true, desc = "Open vertical terminal" }
            )
            vim.keymap.set(
                "n",
                "<Leader>th",
                function() term_toggle "horizontal" end,
                { noremap = true, silent = true, desc = "Open horizontal terminal" }
            )
            vim.keymap.set(
                "n",
                "<Leader>tf",
                function() term_toggle "float" end,
                { noremap = true, silent = true, desc = "Open floating terminal" }
            )
            vim.keymap.set(
                { "n", "i" },
                "<F2>",
                function() term_toggle(direction) end,
                { noremap = true, silent = true, desc = "Toggle term" }
            )
            vim.keymap.set("t", "<F2>", "<Cmd>ToggleTerm<CR>", { noremap = true, silent = true, desc = "Toggle term" })
        end,
    },

    {
        "rebelot/heirline.nvim",
        opts = function(_, opts)
            -- remove lsp progress
            local status = require "astroui.status"
            opts.statusline = {
                status.component.mode(),
                status.component.git_branch(),
                status.component.file_info(),
                status.component.git_diff(),
                status.component.diagnostics(),
                status.component.fill(),
                status.component.cmd_info(),
                status.component.fill(),
                status.component.lsp { lsp_progress = false }, --https://github.com/AstroNvim/astroui/blob/525a900e55c86bdf81c52deacfb9407ae1240fae/lua/astroui/status/component.lua#L157
                status.component.virtual_env(),
                status.component.treesitter(),
                status.component.nav(),
                status.component.mode { surround = { separator = "right" } },
            }
        end,
    },

    {
        "saghen/blink.cmp",
        optional = true,
        opts = {
            completion = {
                menu = {
                    draw = {
                        columns = {
                            { "kind_icon" },
                            { "label", "label_description", gap = 1 },
                            { "source_name" },
                        },
                    },
                },
            },

            keymap = {
                ["<Tab>"] = {
                    "select_next",
                    "snippet_forward",
                    "fallback",
                },
                ["<S-Tab>"] = {
                    "select_prev",
                    "snippet_backward",
                    "fallback",
                },
            },

            -- sources = {
            --     providers = {
            --         cmdline = {
            --             -- ignores cmdline completions when executing shell commands
            --             -- refer to:https://github.com/Saghen/blink.cmp/issues/795
            --             -- I select another ways to fix these issue
            --             enabled = function()
            --                 return vim.fn.getcmdline():sub(1, 1) ~= "!"
            --             end,
            --         },
            --     },
            -- },

            cmdline = {
                completion = {
                    menu = {
                        auto_show = true,
                    },

                    list = {
                        selection = {
                            preselect = false,
                        },
                    },
                },
            },
        },
    },
    {

        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
        opts = {
            file_types = { "markdown", "Avante" },
            completions = { blink = { enabled = true } },
        },
    },
}
