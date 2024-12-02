-- You can also add or configure plugins by creating files in this `plugins/` folder
-- Here are some examples:

---@type LazySpec
return {
    {
        "goolord/alpha-nvim",
        opts = function(_, opts)
            -- customize the dashboard header
            opts.section.header.val = {
                " █████  ███████ ████████ ██████   ██████",
                "██   ██ ██         ██    ██   ██ ██    ██",
                "███████ ███████    ██    ██████  ██    ██",
                "██   ██      ██    ██    ██   ██ ██    ██",
                "██   ██ ███████    ██    ██   ██  ██████",
                " ",
                "    ███    ██ ██    ██ ██ ███    ███",
                "    ████   ██ ██    ██ ██ ████  ████",
                "    ██ ██  ██ ██    ██ ██ ██ ████ ██",
                "    ██  ██ ██  ██  ██  ██ ██  ██  ██",
                "    ██   ████   ████   ██ ██      ██",
            }
            return opts
        end,
    },

    -- You can disable default plugins as follows:
    { "max397574/better-escape.nvim", enabled = true },

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
        dependencies = {
            "rcarriga/nvim-notify",
            opts = {
                timeout = 1500,
                top_down = false,
            },
        },
        opts = {
            presets = {
                bottom_search = false, -- use a classic bottom cmdline for search
                command_palette = true, -- position the cmdline and popupmenu together
                long_message_to_split = true, -- long messages will be sent to a split
                inc_rename = false, -- enables an input dialog for inc-rename.nvim
                lsp_doc_border = false, -- add a border to hover docs and signature help
            },
            lsp = {
                hover = {
                    enabled = false,
                },
                signature = {
                    enabled = false,
                },
            },
        },
    },
    {
        "nvimdev/lspsaga.nvim",
        dependencies = {
            {
                -- AstroCore is always loaded on startup, so making it a dependency doesn't matter
                "AstroNvim/astrolsp",
                opts = {
                    mappings = { -- define a mapping to load the plugin module
                        n = {
                            ["grr"] = false,
                            ["gra"] = false,
                            ["grn"] = false,
                            ["gr"] = { "<cmd>Lspsaga rename<cr>" },
                            ["gD"] = { "<cmd>Lspsaga peek_definition<cr>" },
                            ["<Leader>fu"] = {
                                function()
                                    local astro = require "astrocore"
                                    local is_available = astro.is_available

                                    if is_available "aerial.nvim" then
                                        require("telescope").extensions.aerial.aerial()
                                    else
                                        require("telescope.builtin").lsp_document_symbols()
                                    end
                                end,
                                desc = "Search symbols",
                            },
                            ["<Leader>fi"] = {
                                '<cmd>Telescope lsp_dynamic_workspace_symbols path_display="hidden"<cr>',
                            },
                            ["gh"] = { "<cmd>Lspsaga finder<cr>" },
                        },
                    },
                },
            },
        },
        opts = {
            lightbulb = {
                debounce = 500,
            },
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
        "nvim-telescope/telescope.nvim",
        opts = {
            defaults = {
                mappings = {
                    i = {
                        ["<C-q>"] = require("telescope.actions").file_vsplit,
                    },
                },
            },
        },
    },
    {
        "akinsho/toggleterm.nvim",
        lazy = false,
        dependencies = {
            {
                -- AstroCore is always loaded on startup, so making it a dependency doesn't matter
                "AstroNvim/astrocore",
                opts = {
                    mappings = { -- define a mapping to load the plugin module
                        n = {
                            ["<c-\\>"] = false,
                            ["<Leader>th"] = false,
                            ["<Leader>tv"] = false,
                            ["<Leader>tl"] = false,
                            ["<Leader>gg"] = false,
                        },
                        t = {
                            ["<ESC><ESC>"] = { "<C-\\><C-N>", desc = "return to normal mode" },
                            ["<c-\\>"] = false,
                        },
                    },
                },
            },
        },
        opts = function(plugin, opts)
            local direction = "float"
            opts.size = 20

            opts.on_create = function(t)
                vim.opt_local.foldcolumn = "0"
                vim.opt_local.signcolumn = "no"
            end

            -- used for lazygit
            local Terminal = require("toggleterm.terminal").Terminal
            local lazygit = Terminal:new {
                cmd = "lazygit",
                hidden = true,
                direction = "float",
                count = 10,
            }

            local function lazygit_toggle()
                if vim.fn.bufname("%"):match "^term:" == nil then
                    lazygit.dir = vim.fn.expand "%:p:h" -- current working directory for the active buffer
                    lazygit:toggle()
                end
            end

            vim.keymap.set(
                "n",
                "<Leader>gg",
                function() lazygit_toggle() end,
                { noremap = true, silent = true, desc = "lazygit" }
            )

            -- change direction for terminal
            local function term_toggle(dir)
                local size = opts.size
                direction = dir
                if dir == "vertical" then size = 80 end
                vim.cmd(vim.v.count .. "ToggleTerm" .. " direction=" .. direction .. " size=" .. size)
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
                "n",
                "<c-\\>",
                function() term_toggle(direction) end,
                { noremap = true, silent = true, desc = "Toggle term" }
            )
            vim.keymap.set(
                "t",
                "<c-\\>",
                "<Cmd>ToggleTerm<CR>",
                { noremap = true, silent = true, desc = "Toggle term" }
            )
        end,
    },
    {
        "folke/which-key.nvim",
        opts = {
            delay = 800,
        },
    },
    {
        "JoosepAlviste/nvim-ts-context-commentstring",
        opts = {
            -- adujst default configuration: https://github.com/JoosepAlviste/nvim-ts-context-commentstring/blob/9c74db656c3d0b1c4392fc89a016b1910539e7c0/lua/ts_context_commentstring/config.lua#L66
            languages = {
                c = { __default = "// %s", __multiline = "/* %s */" },
            },
        },
    },
}
