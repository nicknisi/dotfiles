filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#begin()

" let vundle manage vundle
Plugin 'gmarik/vundle'

" utilities
Plugin 'kien/ctrlp.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'mileszs/ack.vim'
Plugin 'Raimondi/delimitMate'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-unimpaired'
Plugin 'tpope/vim-endwise'
Plugin 'tpope/vim-ragtag'
Plugin 'tpope/vim-surround'
Plugin 'benmills/vimux'
Plugin 'bling/vim-airline'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-repeat'
Plugin 'garbas/vim-snipmate'
Plugin 'mattn/emmet-vim'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'sotte/presenting.vim'
Plugin 'ervandew/supertab'
Plugin 'tpope/vim-dispatch'
Plugin 'mtth/scratch.vim'
Plugin 'itspriddle/vim-marked'
Plugin 'tpope/vim-vinegar'
Plugin 'ap/vim-css-color'
Plugin 'davidoc/taskpaper.vim'
Plugin 'tpope/vim-abolish'
Plugin 'AndrewRadev/splitjoin.vim'
Plugin 'godlygeek/tabular'
Plugin 'gbigwood/Clippo'
Plugin 'vim-scripts/matchit.zip'
Plugin 'gregsexton/MatchTag'
Plugin 'tpope/vim-sleuth' " detect indent style (tabs vs. spaces)
Plugin 'sickill/vim-pasta'

" colorschemes
Plugin 'chriskempson/base16-vim'

" JavaScript
Plugin 'othree/html5.vim'
Plugin 'pangloss/vim-javascript'
Plugin 'jelera/vim-javascript-syntax'
" Plugin 'jason0x43/vim-js-syntax'
" Plugin 'jason0x43/vim-js-indent'
Plugin 'wavded/vim-stylus'
Plugin 'groenewege/vim-less'
Plugin 'digitaltoad/vim-jade'
Plugin 'juvenn/mustache.vim'
Plugin 'moll/vim-node'
Plugin 'elzr/vim-json'
Plugin 'leafgarland/typescript-vim'
Plugin 'mxw/vim-jsx'
Plugin 'cakebaker/scss-syntax.vim'
" Plugin 'dart-lang/dart-vim-plugin'
" Plugin 'kchmck/vim-coffee-script'
" Plugin 'Valloric/YouCompleteMe'
" Plugin 'marijnh/tern_for_vim'

" languages
Plugin 'tpope/vim-markdown'
Plugin 'fatih/vim-go'
" Plugin 'tclem/vim-arduino'
Plugin 'timcharper/textile.vim'

call vundle#end()
filetype plugin indent on
