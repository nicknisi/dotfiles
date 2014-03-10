filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let vundle manage vundle
Bundle 'gmarik/vundle'

" utilities
Bundle 'kien/ctrlp.vim'
Bundle 'scrooloose/nerdtree'
Bundle 'mileszs/ack.vim'
Bundle 'Raimondi/delimitMate'
Bundle 'tpope/vim-commentary'
Bundle 'tpope/vim-unimpaired'
Bundle 'tpope/vim-endwise'
Bundle 'tpope/vim-ragtag'
Bundle 'tpope/vim-surround'
Bundle 'benmills/vimux'
Bundle 'bling/vim-airline'
Bundle 'scrooloose/syntastic'
Bundle 'ciaranm/detectindent'
Bundle 'tpope/vim-fugitive'
Bundle 'terryma/vim-multiple-cursors'
Bundle 'tpope/vim-repeat'
Bundle 'tonchis/to-github-vim'
Bundle 'garbas/vim-snipmate'
Bundle 'mattn/emmet-vim'
Bundle 'editorconfig/editorconfig-vim'
Bundle "MarcWeber/vim-addon-mw-utils"
Bundle "tomtom/tlib_vim"
Bundle 'sotte/presenting.vim'
Bundle 'ervandew/supertab'

" colorschemes
Bundle 'ap/vim-css-color'
Bundle 'flazz/vim-colorschemes'
Bundle 'nanotech/jellybeans.vim'
Bundle 'w0ng/vim-hybrid'

" languages
Bundle 'othree/html5.vim'
Bundle 'pangloss/vim-javascript'
Bundle 'tpope/vim-markdown'
Bundle 'wavded/vim-stylus'
Bundle 'groenewege/vim-less'
Bundle 'digitaltoad/vim-jade'
Bundle 'juvenn/mustache.vim'
Bundle 'moll/vim-node'
Bundle 'elzr/vim-json'
Bundle 'leafgarland/typescript-vim'
" Bundle 'jnwhiteh/vim-golang'
" Bundle 'dart-lang/dart-vim-plugin'
Bundle 'cakebaker/scss-syntax.vim'
" Bundle 'kchmck/vim-coffee-script'
Bundle 'tclem/vim-arduino'

filetype plugin indent on
