"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General Config:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" === General Config === {{{

syntax on

" Enable filetype plugins
filetype indent plugin on 

" if hidden is not set, TextEdit might fail.
set hidden

"Better display for messages
set cmdheight=2

"" Smaller updatetime for CursorHold & CursorHoldI
set updatetime=100

"" don't give |ins-completion-menu| messages.
set shortmess+=c

"" always show signcolumns
set signcolumn=yes

set autoread            "Set to auto read when a file is changed from the outside
set autowrite           " Save automatically all the buffers in vim
set noautochdir         " Set the working directory

set ruler               " Always show current position

set showmatch           " highlight matching [{()}]

set timeoutlen=1000 ttimeoutlen=0

set nobackup
set nowb
set noswapfile

set expandtab
set smarttab            " Handle tabs more intelligently

set autoindent
set cindent
set ts=4 sts=4 sw=4 expandtab smarttab
set cino+=j1,(0,ws,Ws
set cinoptions+=g0

set number              " show line numbers
set relativenumber
set showcmd             " show command in bottom bar
set showtabline=2       " show tabline in top bar

set cursorline          " highlight current line

set wildmenu            " visual autocomplete for command menu
set wildmode=longest:full

set lazyredraw          " redraw only when we need to

set incsearch           " search as characters are entered
set hlsearch            " highlight matcheso
set ignorecase 
set smartcase
let @/ = ""             " no highlight after source vimrc

set list
set listchars=tab:┆\ 
set listchars+=eol:¬
set listchars+=trail:·,extends:→

set backspace=indent,eol,start
set nowrap

set formatoptions-=r formatoptions-=c formatoptions-=o " Disable newline with comment

set noeb vb t_vb=       " Tell vim to shut up

set mouse=a

set sidescrolloff=30   " keep 30 columns visible left and right of the cursor at all times

set noeol

let g:vimsyn_embed= 'l' "highlighting embedded script inside vim files
" }}}

" === Apperance === {{{
set termguicolors
set background=dark

" color intellij
" color dalton
let g:gruvbox_material_background = 'hard'
let g:gruvbox_material_enable_italic = 1
" let g:gruvbox_material_disable_italic_comment = 1

color gruvbox-material
" color gruvbox
" }}}

" {{{ === Statusline
set statusline=
set statusline+=\ %n\                              " Buffer number
set statusline+=\ %<%f%m%r%h%w\                    " File path, modified, readonly, helpfile, preview
" set statusline+=│                                 " Separator
" set statusline+=\ (%{&ff})                        " FileFormat (dos/unix..)
set statusline+=%=                                 " Right Side
set statusline+=%{coc#status()}%{get(b:,'coc_current_function','')}
" set statusline+=│                                 " Separator
" set statusline+=\ col:\ %02v\                     " Colomn number
set statusline+=\ %Y\                              " FileType
set statusline+=│                                  " Separator
set statusline+=\ %{''.(&fenc!=''?&fenc:&enc).''}\ " Encoding
set statusline+=│                                  " Separator
set statusline+=\ %l:%c                            " Line number / total lines
set statusline+=\ %p%%\                            " Percentage of document
" }}}

" {{{ === Tabline
function! Tabline()
  let s = ''
  for i in range(tabpagenr('$'))
    let tab = i + 1
    let winnr = tabpagewinnr(tab)
    let buflist = tabpagebuflist(tab)
    let bufnr = buflist[winnr - 1]
    let bufname = bufname(bufnr)
    let bufmodified = getbufvar(bufnr, "&mod")

    let s .= '%' . tab . 'T'
    let s .= (tab == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#')
    let s .= ' ' . tab .'.'
    let s .= (bufname != '' ? '['. fnamemodify(bufname, ':t') . ']' : '[No Name]')
    let s .= (bufmodified ? '[+]' : '')
    let s .= ' %#TabLine#│'

  endfor

  let s .= '%#TabLineFill#'
  return s
endfunction
set tabline=
set tabline+=%!Tabline()
" }}}

" === Autocmd === {{{
if has("autocmd")

  augroup coc-explorer
    autocmd!
    autocmd FileType coc-explorer setlocal statusline=Explorer
  augroup END

  " Disable newline with comment
  augroup newline
    autocmd!
    autocmd BufEnter * set fo-=c fo-=r fo-=o
  augroup END

  " Auto disable syntax with large file
  augroup syntaxoff
    autocmd!
    autocmd Filetype * if getfsize(expand("%")) > 100000 | setlocal syntax=OFF | endif
  augroup END

  " Back to line
  augroup line
    autocmd!
    au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
  augroup END

  " Auto disable folding with large file
  augroup fold
    autocmd!
    autocmd FileType * if getfsize(expand("%")) < 100000 | setlocal foldmethod=marker foldlevel=0 | endif 
    autocmd FileType go if getfsize(expand("%")) < 10000 | setlocal foldmethod=syntax foldlevel=20 | endif 
  augroup END

  " Syntax of these languages is fussy over tabs Vs spaces
  augroup filetype
    autocmd!
    autocmd FileType make       setlocal ts=8 sts=8 sw=8 noexpandtab
    autocmd FileType yaml       setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType html       setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType css        setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType typescript setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType javascript setlocal ts=4 sts=4 sw=4 expandtab
    autocmd FileType json       setlocal ts=4 sts=4 sw=4 expandtab
    autocmd FileType cpp        setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
    autocmd FileType go         setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
    autocmd FileType php        setlocal ts=4 sts=4 sw=4 expandtab smarttab
    autocmd FileType vim        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType sh         setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType zsh        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType lua        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType sql        setlocal ts=4 sts=4 sw=4 expandtab smarttab
    autocmd FileType xml        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType proto      setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
  augroup END

  augroup templates
    autocmd!
    autocmd BufNewFile *.cpp 0r ~/.vim/templates/skeleton.cpp
  augroup END
  
endif
" }}}
