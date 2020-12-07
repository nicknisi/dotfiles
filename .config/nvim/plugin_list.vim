"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

call plug#begin('~/.local/share/nvim/plugged')

Plug 'nvim-treesitter/nvim-treesitter'

Plug 'diepm/vim-rest-console'

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

" ctags bar
Plug 'majutsushi/tagbar'

" vim-tmux-navigation
Plug 'christoomey/vim-tmux-navigator'

" colorscheme
Plug 'chiendo97/intellij.vim'
Plug 'morhetz/gruvbox'
Plug 'sainnhe/gruvbox-material'
Plug 'edersonferreira/dalton-vim'

" resize vim windows with ctrl + T
Plug 'simeji/winresizer'

" helpful with surround"
Plug 'machakann/vim-sandwich'

" find file with name"
Plug '/usr/local/opt/fzf'
Plug 'junegunn/fzf.vim'

"{{{ === Syntax and languages
Plug 'ap/vim-css-color'
Plug 'fatih/vim-go'
Plug 'derekwyatt/vim-scala'
Plug 'cespare/vim-toml'
" Plug 'sheerun/vim-polyglot'
" Plug 'HerringtonDarkholme/yats.vim'
" Plug 'mattn/emmet-vim'
"}}}

" comment 
Plug 'scrooloose/nerdcommenter'

" coc for completion"
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" directory tree
Plug 'ryanoasis/vim-devicons'

call plug#end()
