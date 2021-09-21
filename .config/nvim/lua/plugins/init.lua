vim.cmd([[packadd packer.nvim]])

return require("packer").startup(function(use)
    -- Packer can manage itself as an optional plugin
    use({ "wbthomason/packer.nvim", event = "VimEnter" })

    -- add packages

    -- nerdtree alternate
    use({
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        config = function()
            require("plugins.tree")
        end,
    })

    -- lspconfig
    use({
        "neovim/nvim-lspconfig",
        config = function()
            require("lsp")
        end,
    })

    -- lsp autocomplete
    use({
        "hrsh7th/nvim-cmp",
        requires = {
            "hrsh7th/cmp-buffer", -- buffer source
            "hrsh7th/cmp-nvim-lsp", -- lsp source
            "hrsh7th/cmp-nvim-lua", -- neovim's Lua runtime API such vim.lsp.* source
            "hrsh7th/cmp-path", -- path source
            "hrsh7th/cmp-vsnip", -- vsnip source
            "hrsh7th/vim-vsnip", -- snippet
        },
        config = function()
            require("plugins.nvim_cmp")
        end,
    })

    -- go vscode snippet
    use("rafamadriz/friendly-snippets")

    -- add brackets
    use("machakann/vim-sandwich")

    -- treesitter syntax
    use({
        "nvim-treesitter/nvim-treesitter",
        event = "BufRead",
        run = ":TSUpdate",
        config = function()
            require("plugins.treesitter")
        end,
    })
    -- disable because of slow startup.
    --[[ use({
        "nvim-treesitter/nvim-treesitter-textobjects",
        after = { "nvim-treesitter" },
    }) ]]

    -- align text with ga=
    use({
        "junegunn/vim-easy-align",
        config = function()
            local map = vim.api.nvim_set_keymap

            -- Start interactive EasyAlign in visual mode (e.g. vipga)
            map("x", "ga", "<Plug>(EasyAlign)", {})
            -- Start interactive EasyAlign for a motion/text object (e.g. gaip)
            map("n", "ga", "<Plug>(EasyAlign)", {})
        end,
    })

    -- Preview markdown live: :MarkdownPreview
    use({
        "iamcco/markdown-preview.nvim",
        run = "cd app && yarn install",
        ft = "markdown",
        cmd = "MarkdownPreview",
        opt = true,
    })

    -- Some Git stuff
    use({
        "lewis6991/gitsigns.nvim",
        requires = { "nvim-lua/plenary.nvim" },
        config = function()
            require("plugins.gitgutter")
        end,
    })

    use({
        "tpope/vim-fugitive",
    })

    -- vim-tmux-navigation
    use({
        "christoomey/vim-tmux-navigator",
        config = function()
            vim.g.tmux_navigator_disable_when_zoomed = 1
        end,
    })

    -- colorscheme
    use({
        "eddyekofo94/gruvbox-flat.nvim",
        config = function()
            vim.opt.termguicolors = true
            vim.opt.background = "dark"

            vim.g.gruvbox_flat_style = "hard"
            vim.g.gruvbox_sidebars = { "qf", "vista_kind", "terminal", "packer" }
            vim.g.gruvbox_hide_inactive_statusline = true
            vim.cmd("colorscheme gruvbox-flat")
        end,
    })

    use({
        "nvim-telescope/telescope.nvim",
        requires = {
            { "nvim-lua/popup.nvim" },
            { "nvim-lua/plenary.nvim" },
            { "nvim-telescope/telescope-fzy-native.nvim" },
        },
        config = function()
            require("plugins.telescope")
        end,
    })

    -- Syntax and languages
    use({
        "norcalli/nvim-colorizer.lua",
        disable = true,
        event = "BufRead",
        opt = true,
        config = function()
            require("colorizer").setup()
        end,
    })

    -- comment
    use({
        "b3nj5m1n/kommentary",
        config = function()
            vim.g.kommentary_create_default_mappings = false

            vim.api.nvim_set_keymap("n", "<C-_>", "<Plug>kommentary_line_default", {})
            vim.api.nvim_set_keymap("v", "<C-_>", "<Plug>kommentary_visual_default", {})
        end,
    })

    -- generate go test
    use({
        "buoto/gotests-vim",
        ft = "go",
        opt = true,
    })

    --[[ use({
        "fatih/vim-go",
        lock = true,
        ft = "go",
        opt = true,
        config = function()
            vim.g.go_fold_enable = false
            vim.g.go_code_completion_enabled = 0
            vim.g.go_doc_keywordprg_enabled = 0
            vim.g.go_def_mapping_enabled = 0
            vim.g.go_textobj_enabled = 0
            vim.g.go_metalinter_autosave_enabled = 0
            vim.g.go_metalinter_enabled = 0
            vim.g.go_term_enabled = 0
            vim.g.go_gopls_enabled = 0
            vim.g.go_diagnostics_enabled = 0
        end,
    }) ]]

    -- better quickfix
    use({
        "kevinhwang91/nvim-bqf",
        config = function()
            require("plugins.nvim-bqf")
        end,
        ft = { "qf" },
    })

    use({
        "lukas-reineke/indent-blankline.nvim",
        event = "BufRead",
        config = function()
            require("plugins.indent-blankline")
        end,
    })

    use("leafgarland/typescript-vim")
    use("peitalin/vim-jsx-typescript")

    use({
        "jose-elias-alvarez/null-ls.nvim",
        config = function()
            require("lsp.null-ls")
        end,
        requires = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    })

    use({
        "kristijanhusak/orgmode.nvim",
        config = function()
            require("plugins.org")
        end,
    })

    --[[ use {
        'nvim-neorg/neorg',
        config = function()
            require('plugins.neorg')
        end,
        requires = 'nvim-lua/plenary.nvim'
    } ]]

    -- Lua
    use({
        "folke/which-key.nvim",
        config = function()
            require("which-key").setup({})
        end,
        event = "VimEnter",
    })
end)
