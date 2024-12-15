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
            diagnostics_mode = 3, -- diagnostic mode on start (0 = off, 1 = no signs/virtual text, 2 = no virtual text, 3 = on)
            highlighturl = true, -- highlight URLs at start
            notifications = true, -- enable notifications at start
        },
        -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
        diagnostics = {
            virtual_text = true,
            underline = true,
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
            -- see :h map-mode
            n = {
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
            },
            t = {
                ["<C-L>"] = false,
            },
        },

        autocmds = {
            -- disable alpha autostart
            alpha_autostart = false,
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
    },
}
