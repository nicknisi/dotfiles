filetype off

" set rtp+=~/.vim/bundle/vundle/
call plug#begin('~/.vim/plugged')

" let vundle manage vundle
" Plugin 'gmarik/vundle'

" utilities
Plug 'kien/ctrlp.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' } | Plug 'Xuyuanp/nerdtree-git-plugin' | Plug 'ryanoasis/vim-devicons'
Plug 'mileszs/ack.vim'
Plug 'Raimondi/delimitMate'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-ragtag'
Plug 'tpope/vim-surround'
Plug 'benmills/vimux'
Plug 'bling/vim-airline'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-repeat'
Plug 'garbas/vim-snipmate'
Plug 'mattn/emmet-vim'
Plug 'editorconfig/editorconfig-vim'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'sotte/presenting.vim'
Plug 'ervandew/supertab'
Plug 'tpope/vim-dispatch'
" Plug 'mtth/scratch.vim'
Plug 'itspriddle/vim-marked', { 'for': 'markdown', 'on': 'MarkedOpen' }
Plug 'tpope/vim-vinegar'
Plug 'ap/vim-css-color'
Plug 'davidoc/taskpaper.vim'
Plug 'tpope/vim-abolish'
Plug 'AndrewRadev/splitjoin.vim'
Plug 'godlygeek/tabular'
Plug 'vim-scripts/matchit.zip'
Plug 'gregsexton/MatchTag'
Plug 'tpope/vim-sleuth' " detect indent style (tabs vs. spaces)
Plug 'sickill/vim-pasta'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" colorschemes
Plug 'chriskempson/base16-vim'

" JavaScript
Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'jelera/vim-javascript-syntax', { 'for': 'javascript' }
" Plug 'jason0x43/vim-js-syntax'
" Plug 'jason0x43/vim-js-indent'
Plug 'wavded/vim-stylus', { 'for': 'stylus' }
Plug 'groenewege/vim-less', { 'for': 'less' }
Plug 'digitaltoad/vim-jade', { 'for': 'jade' }
Plug 'juvenn/mustache.vim', { 'for': 'mustache' }
Plug 'moll/vim-node', { 'for': 'javascript' }
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'Quramy/tsuquyomi', { 'for': 'typescript', 'do': 'npm install' }
" Plug 'mxw/vim-jsx'
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
" Plug 'dart-lang/dart-vim-plugin'
" Plug 'kchmck/vim-coffee-script'
" Plug 'Valloric/YouCompleteMe'
" Plug 'marijnh/tern_for_vim'

" languages
Plug 'tpope/vim-markdown', { 'for': 'markdown' }
Plug 'fatih/vim-go', { 'for': 'go' }
" Plug 'tclem/vim-arduino'
Plug 'timcharper/textile.vim', { 'for': 'textile' }

call plug#end()
filetype plugin indent on
