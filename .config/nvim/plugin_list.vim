"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

call plug#begin('~/.local/share/nvim/plugged')

Plug 'kyazdani42/nvim-web-devicons' " for file icons
Plug 'kyazdani42/nvim-tree.lua'

Plug 'neovim/nvim-lspconfig'

Plug 'hrsh7th/vim-vsnip'
Plug 'hrsh7th/nvim-compe'

Plug 'machakann/vim-sandwich'

" treesitter syntax
Plug 'nvim-treesitter/nvim-treesitter'

" show git commit
Plug 'rhysd/git-messenger.vim'

" align text ga=
Plug 'junegunn/vim-easy-align'

" Macro editing: <leader>q + register
Plug 'zdcthomas/medit'

" Vim wiki <leader>ww to open
Plug 'vimwiki/vimwiki'

" Preview markdown live: :Mark
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() } }

" Vim plugin that provides additional text objects
Plug 'wellle/targets.vim'

" Some Git stuff
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'

" vim-tmux-navigation
Plug 'christoomey/vim-tmux-navigator'

" colorscheme
" Plug 'sainnhe/gruvbox-material'
Plug 'eddyekofo94/gruvbox-flat.nvim'

" resize vim windows with ctrl + T
Plug 'simeji/winresizer'

" find file with name"
Plug '/usr/local/opt/fzf'
Plug 'junegunn/fzf.vim'

" Syntax and languages
Plug 'mattn/emmet-vim'
Plug 'ap/vim-css-color'
Plug 'fatih/vim-go'

" comment 
Plug 'scrooloose/nerdcommenter'

call plug#end()
