vim.cmd 'packadd paq-nvim' -- load package
local paq = require('paq-nvim').paq -- import module with `paq` function
paq {'savq/paq-nvim', opt = true} -- let paq manage itself

-- add packages

paq 'kyazdani42/nvim-web-devicons' -- 'for file icons
paq 'kyazdani42/nvim-tree.lua'

paq 'neovim/nvim-lspconfig'

paq 'hrsh7th/nvim-compe'
paq 'hrsh7th/vim-vsnip'
paq 'hrsh7th/vim-vsnip-integ'
paq 'golang/vscode-go'

paq 'machakann/vim-sandwich'

-- 'treesitter syntax
paq 'nvim-treesitter/nvim-treesitter'

-- 'show git commit
paq 'rhysd/git-messenger.vim'

-- 'align text ga=
paq 'junegunn/vim-easy-align'

-- 'Preview markdown live: :Mark
paq 'iamcco/markdown-preview.nvim'

-- 'Vim plugin that provides additional text objects
paq 'wellle/targets.vim'

-- 'Some Git stuff
paq 'airblade/vim-gitgutter'
paq 'tpope/vim-fugitive'

-- 'vim-tmux-navigation
paq 'christoomey/vim-tmux-navigator'

-- 'colorscheme
paq 'eddyekofo94/gruvbox-flat.nvim'

-- 'resize vim windows with ctrl + T
paq 'simeji/winresizer'

-- 'find file with name"
paq 'junegunn/fzf'
paq 'junegunn/fzf.vim'
paq {'ojroques/nvim-lspfuzzy'}

-- 'Syntax and languages
paq 'mattn/emmet-vim'
paq 'ap/vim-css-color'

-- 'comment
paq 'b3nj5m1n/kommentary'

paq {'fatih/vim-go', branch = "v1.25"}

paq {'buoto/gotests-vim'}

paq {'kevinhwang91/nvim-bqf'}
