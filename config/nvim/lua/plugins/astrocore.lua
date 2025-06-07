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
