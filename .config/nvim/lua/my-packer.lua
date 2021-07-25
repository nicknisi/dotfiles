-- This file can be loaded by calling `lua require('plugins')` from your init.vim
-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)

    -- Packer can manage itself as an optional plugin
    use {'wbthomason/packer.nvim', event = 'VimEnter'}

    -- add packages

    -- nerdtree alternate
    use {
        'kyazdani42/nvim-tree.lua',
        requires = {'kyazdani42/nvim-web-devicons'},
        config = function()
            require 'plugins.tree'
        end
    }

    -- lspconfig
    use {
        'neovim/nvim-lspconfig',
        config = function()
            require('lsp')
        end
    }

    -- lsp autocomplete
    use {
        'hrsh7th/nvim-compe',
        event = 'InsertEnter',
        config = function()
            require('plugins.nvim_compe')
        end
    }
    use 'hrsh7th/vim-vsnip'
    use 'hrsh7th/vim-vsnip-integ'

    -- go vscode snippet
    use 'golang/vscode-go'

    -- add brackets
    use 'machakann/vim-sandwich'

    -- treesitter syntax
    use {
        'nvim-treesitter/nvim-treesitter',
        event = 'BufRead',
        config = function()
            require('plugins.treesitter')
        end
    }
    use {
        'nvim-treesitter/nvim-treesitter-textobjects',
        after = {'nvim-treesitter'}
    }

    -- align text ga=
    -- use 'junegunn/vim-easy-align'

    -- Preview markdown live: :Mark
    -- use 'iamcco/markdown-preview.nvim'

    -- Vim plugin that provides additional text objects
    -- use 'wellle/targets.vim'

    -- Some Git stuff
    use {
        'lewis6991/gitsigns.nvim',
        requires = {'nvim-lua/plenary.nvim'},
        config = function()
            require('plugins.gitgutter')
        end
    }

    -- use {'tpope/vim-fugitive', cmd = {'Gread', 'Gwrite', 'Gcommit'}}

    -- vim-tmux-navigation
    use {
        'christoomey/vim-tmux-navigator',
        config = function()
            vim.g.tmux_navigator_disable_when_zoomed = 1
        end
    }

    -- colorscheme
    use {
        'eddyekofo94/gruvbox-flat.nvim',
        config = function()
            vim.opt.termguicolors = true
            vim.opt.background = 'dark'
            vim.g.gruvbox_flat_style = 'dark'
            vim.cmd 'colorscheme gruvbox-flat'
        end
    }

    -- find file with name
    use {
        'nvim-telescope/telescope.nvim',
        requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}},
        config = function()
            require('plugins.fzf')
        end
    }

    -- Syntax and languages
    use {
        'norcalli/nvim-colorizer.lua',
        event = 'BufRead',
        config = function()
            require'colorizer'.setup()
        end
    }

    -- comment
    use {
        'b3nj5m1n/kommentary',
        config = function()
            require 'plugins.kommentary'
        end
    }

    -- some go functions
    -- use 'fatih/vim-go'

    -- generate go test
    use {'buoto/gotests-vim', cmd = 'GoTests'}

    -- better quickfix
    use {
        'kevinhwang91/nvim-bqf',
        config = function()
            require('bqf').setup({func_map = {openc = '<esc>'}})
        end
    }

    -- auto lsp signature
    use 'ray-x/lsp_signature.nvim'

end)
