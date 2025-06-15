-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
        -- Configure core features of AstroNvim
        features = {
            large_buf = { size = 1024 * 5000, lines = 80000 }, -- set global limits for large files for disabling features like treesitter
            autopairs = true, -- enable autopairs at start
            cmp = true, -- enable completion at start
            diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
            highlighturl = true, -- highlight URLs at start
            notifications = true, -- enable notifications at start
        },
        -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
        diagnostics = {
            virtual_text = true,
            underline = true,
        },
        -- passed to `vim.filetype.add`
        filetypes = {
            -- see `:h vim.filetype.add` for usage
            extension = {
                foo = "fooscript",
            },
            filename = {
                [".foorc"] = "fooscript",
            },
            pattern = {
                [".*/etc/foo/.*"] = "fooscript",
            },
        },
        -- vim options can be configured here
        options = {
            opt = { -- vim.opt.<key>
                relativenumber = true, -- sets vim.opt.relativenumber
                number = true, -- sets vim.opt.number
                signcolumn = "yes", -- sets vim.opt.signcolumn to yes
                wrap = false, -- sets vim.opt.wrap
                smartindent = true,
                shiftwidth = 4,
                backup = false,
                splitbelow = true, -- force all horizontal splits to go below current window
                splitright = true, -- force all vertical splits to go to the right of current window
                swapfile = false, -- creates a swapfile
                updatetime = 300, -- faster completion (4000ms default)
                writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
                expandtab = true, -- convert tabs to spaces
                foldcolumn = "0",
                jumpoptions = "view",
                spell = false, -- sets vim.opt.spell
            },
            g = { -- vim.g.<key>
                -- configure global vim variables (vim.g)
                -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
                -- This can be found in the `lua/lazy_setup.lua` file
            },
        },

        autocmds = {
            luasnip_unlink_current = {
                -- the value is a list of autocommands to create
                {
                    -- ref:https://github.com/L3MON4D3/LuaSnip/issues/747#issuecomment-1406946217
                    -- event is added here as a string or a list-like table of events
                    event = "CursorMovedI",
                    -- the rest of the autocmd options (:h nvim_create_autocmd)
                    desc = "Leave snippet",
                    callback = function(ev)
                        local ls = require "luasnip"
                        if not ls.session or not ls.session.current_nodes[ev.buf] or ls.session.jump_active then
                            return
                        end

                        local current_node = ls.session.current_nodes[ev.buf]
                        local current_start, current_end = current_node:get_buf_position()
                        current_start[1] = current_start[1] + 1 -- (1, 0) indexed
                        current_end[1] = current_end[1] + 1 -- (1, 0) indexed
                        local cursor = vim.api.nvim_win_get_cursor(0)

                        if
                            cursor[1] < current_start[1]
                            or cursor[1] > current_end[1]
                            or cursor[2] < current_start[2]
                            or cursor[2] > current_end[2]
                        then
                            ls.unlink_current()
                        end
                    end,
                },
            },

            copilot_chat = {
                {
                    event = "BufEnter",
                    pattern = "copilot-*",
                    callback = function()
                        -- Set buffer-local options
                        vim.opt_local.relativenumber = false
                        vim.opt_local.number = false
                        vim.opt_local.conceallevel = 0
                        vim.opt_local.foldcolumn = "0"
                    end,
                },
            },

            restore_session = {
                {
                    event = "VimEnter",
                    desc = "Restore previous directory session if neovim opened with no arguments",
                    nested = true, -- trigger other autocommands as buffers open
                    callback = function()
                        -- Only load the session if nvim was started with no args
                        if vim.fn.argc(-1) == 0 then
                            -- try to load a directory session using the current working directory
                            require("resession").load(vim.fn.getcwd(), { dir = "dirsession", silence_errors = true })
                        end
                    end,
                },
            },
        },

        -- Mappings can be configured through AstroCore as well.
        -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
        mappings = {
            -- first key is the mode
            n = {
                -- second key is the lefthand side of the map
                -- navigate buffer tabs
                ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
                ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

                -- mappings seen under group name "Buffer"
                ["<Leader>bd"] = {
                    function()
                        require("astroui.status.heirline").buffer_picker(
                            function(bufnr) require("astrocore.buffer").close(bufnr) end
                        )
                    end,
                    desc = "Close buffer from tabline",
                },

                -- navigate buffer tabs
                ["<Leader>r"] = { "<cmd>Neotree focus<cr>" },
                ["<A-,>"] = { "<C-o>", desc = "go back" },
                ["<A-.>"] = { "<C-i>", desc = "go forward" },
                ["<A-\\>"] = { "<C-w>x", desc = "exchange windows" },

                -- Comments
                ["<Leader>/"] = false,

                -- setting a mapping to false will disable it
                ["<Leader>o"] = false,
                ["<C-Q>"] = false,

                -- snacks picker keymap
                ["<Leader>fC"] = {
                    function() require("snacks").picker.command_history() end,
                    desc = "Find commands history",
                },

                -- terminal keymap
                ["<c-\\>"] = false,
                ["<F7>"] = false,
                ["<F2>"] = { '<Cmd>execute v:count . "ToggleTerm"<CR>', desc = "Toggle terminal" },
            },

            v = {
                [">"] = { ">gv", desc = "shift right with reselected range" },
                ["<"] = { "<gv", desc = "shift right with reselected range" },
            },

            c = {
                ["<A-h>"] = { "<Left>", desc = "move cursor in insert mode" },
                ["<A-l>"] = { "<Right>", desc = "move cursor in insert mode" },
                ["<A-k>"] = { "<Up>", desc = "move cursor in insert mode" },
                ["<A-j>"] = { "<Down>", desc = "move cursor in insert mode" },
            },

            i = {
                ["<A-h>"] = { "<Left>", desc = "move cursor in insert mode" },
                ["<A-l>"] = { "<Right>", desc = "move cursor in insert mode" },
                ["<A-k>"] = { "<Up>", desc = "move cursor in insert mode" },
                ["<A-j>"] = { "<Down>", desc = "move cursor in insert mode" },
                ["<F7>"] = false,
                ["<F2>"] = { "<Esc><Cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
            },
            t = {
                ["<C-L>"] = false,
                ["<c-\\>"] = false,
                ["<F7>"] = false,
                ["<F2>"] = { "<Cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
                ["<ESC><ESC>"] = { "<C-\\><C-N>", desc = "return to normal mode" },
            },
        },
    },
}
