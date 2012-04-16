" vim settings

" Pathogen
" loads all plugins places in the ~/.vim/bundle directory
call pathogen#infect()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"set winwidth=120

set nocompatible " not compatible with vi
set autoread " detect when a file is changed

" make backspace behave in a sane manner
set backspace=indent,eol,start

" set a map leader for more key combos
let mapleader = ","
let g:mapleader = ","

" change history to 1000
set history=10000

" Tab control
set smarttab 
set expandtab 
set shiftwidth=4
set tabstop=4
set softtabstop=4

"set notimeout
"set ttimeout
"set ttimeoutlen=10

" faster redrawing
set ttyfast

" allow matching of if/end, etc. with %
runtime macros/matchit.vim

" highlight conflicts
match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'

" Enable file type detection and do language dependent indenting
filetype plugin indent on

" file type specific settings
if has("autocmd")
    autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType make setlocal ts=8 sts=8 sw=8 noexpandtab
    autocmd FileType ruby setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType html setlocal ts=4 sts=4 sw=4 expandtab
    autocmd WinEnter * setlocal cursorline
    autocmd WinLeave * setlocal nocursorline
    " automatically resize panes on resize
    autocmd VimResized * exe "normal! \<c-w>="
    "autocmd BufWritePost .vimrc source $MYVIMRC
    " save all files on focus lost, ignoring warnings about untitled buffers
    autocmd FocusLost * silent! wa
endif

" code folding settings
set foldmethod=syntax " fold based on indent
set foldnestmax=10 " deepest fold is 10 levels
set nofoldenable " don't fold by default
set foldlevel=1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => User Interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set so=7 " set 7 lines to the cursors - when moving vertical
set wildmenu " enhanced command line completion
set hidden " current buffer can be put into background
set showcmd " show incomplete commands
set noshowmode " don't show which mode disabled for PowerLine
set wildmode=list:longest " complete files like a shell
set scrolloff=3 " lines of text around cursor
set shell=/bin/bash
set ruler " show postiion in file
set cmdheight=1 " command bar height

set title " set terminal title

" Searching
set ignorecase " case insensitive searching
set smartcase " case-sensitive if expresson contains a capital letter
set hlsearch
set incsearch " set incremental search, like modern browsers
set nolazyredraw " don't redraw while executing macros

set magic " Set magic on, for regex

set showmatch " show matching braces
set mat=2 " how many tenths of a second to blink

" switch to line when editing and block when not
let cursor_to_bar   = "\<Esc>]50;CursorShape=1\x7"
let cursor_to_block = "\<Esc>]50;CursorShape=0\x7"
let &t_SI = cursor_to_bar
let &t_EI = cursor_to_block

" error bells
set noerrorbells
set visualbell
set t_vb=
set tm=500

" switch syntax highlighting on
syntax on

set background=dark
"colorscheme molokai 
colorscheme ir_black
"colorscheme mango
"colorscheme mustang
"colorscheme vividchalk
"colorscheme desert
"colorscheme solarized

set number " show line numbers

set wrap " turn on line wrapping
"set nowrap "turn off line wrapping
set wrapmargin=8 " wrap lines when coming within n characters from side
set linebreak " set soft wrapping
set showbreak=… " show ellipsis at breaking

set autoindent " automatically set indent of new line

set encoding=utf8
set t_Co=256 " Explicitly tell vim that the terminal supports 256 colors"
try
    lang en_US
catch
endtry

" set ffs=unix,mac,dos "default file types

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Files, backups, and undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"set nobackup
"set nowritebackup
"set noswapfile
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => StatusLine
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set laststatus=2 " show the satus line all the time

"set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ %{fugitive#statusline()}\ Dir:%r%{CurDir()}%h\ \ \ Line:%l/%L\ Column:%c
" set statusline=[%n]\ %<%.99f\ %h%w%m%r%y\ %{fugitive#statusline()}%=%-16(\ %l:%L,\ %c-%v\ %)%P
function! CurDir()
    let curdir = getcwd()
    return curdir
endfunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" General mappings/shortcuts for functionality
" Additional, plugin-specific mappings are located under
" the plugins section
"
nnoremap K :q<cr>

" remove extra whitespace
nmap <leader><space> :%s/\s\+$<cr>

" set paste toggle
set pastetoggle=<F6>

" fast saving
nmap <leader>w :w!<cr>

" edit ~/.vimrc
map <leader>e :e! ~/.vimrc<cr>

" clear highlighted search
noremap <space> :set hlsearch! hlsearch?<cr>

" toggle invisible characters
set invlist
set listchars=tab:▸\ ,eol:¬,trail:⋅,extends:❯,precedes:❮
set showbreak=↪
nmap <leader>l :set list!<cr>

" Textmate style indentation
vmap <leader>[ <gv
vmap <leader>] >gv
nmap <leader>[ <<
nmap <leader>] >>

" easier begin/end nav map
"noremap HH ^
"noremap LL $

" buffer shortcuts
nmap <leader>n :bn<cr> " go to next buffer
nmap <leader>p :bp<cr> " go to prev buffer
nmap <leader>q :bd<cr> " close the current buffer

" disable arrow keys (forced learning)
"noremap <Up> ""
"noremap! <Up> <Esc>
"noremap <Down> ""
"noremap! <Down> <Esc>
"noremap  <Left> ""
"noremap! <Left> <Esc>
"noremap  <Right> ""
"noremap! <Right> <Esc>

" Window movement shortcuts
" move to the window in the direction shown, or create a new window
function! WinMove(key)
    let t:curwin = winnr()
    exec "wincmd ".a:key
    if (t:curwin == winnr())
        if (match(a:key,'[jk]'))
            wincmd v
        else
            wincmd s
        endif
        exec "wincmd ".a:key
    endif
endfunction

map <silent> <C-h> :call WinMove('h')<cr>
map <silent> <C-j> :call WinMove('j')<cr>
map <silent> <C-k> :call WinMove('k')<cr>
map <silent> <C-l> :call WinMove('l')<cr>

map <leader>wc :wincmd q<cr>
map <leader>wr <C-W>r

" window movement shortcuts
"map <C-h> <C-w>h " go to window left
"map <C-j> <C-w>j " go to window down
"map <C-k> <C-w>k " go to window up
"map <C-l> <C-w>l " go to window right

" equalize windows
map <leader>= <C-w>=

" Edit Shortcuts
" these automatically populate the current filepath
cnoremap %% <C-R>=expand('%:h').'/'<cr>
map <leader>ew :e %%
map <leader>es :sp %%
map <leader>ev :vsp %%
map <leader>et :tabe %%

" Moving shortcuts
" Instead of pressing g$, press command
vmap <D-j> gj
vmap <D-k> gk
vmap <D-4> g$
vmap <D-6> g^
vmap <D-0> g^
nmap <D-j> gj
nmap <D-k> gk
nmap <D-4> g$
nmap <D-6> g^
nmap <D-0> g^

" toggle cursor line
nnoremap <leader>i :set cursorline!<cr>

" map ; to : in normal mode
"nnoremap ; :

" remap jj in insert mode to ESC
"inoremap jj <Esc>

" use space bar to toggle folds
"nnoremap <Space> za
"vnoremap <Space> za

" scroll the viewport faster
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" moving up and down work as you would expect
nnoremap <silent> j gj
nnoremap <silent> k gk

" toggle paste
map <leader>v :set paste!<cr>

" find out what syntax group the selected text belongs to
nmap <A-S-P> :call SynStack()<cr>
function! SynStack()
    if !exists("*Synstack")
        return
    endif
    echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name"')
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugins
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Powerline settings
let g:Powerline_symbols = 'fancy'
let g:Powerline_stl_path_style = 'filename'

" Toggle NERDTree
nmap <silent> <leader>k :NERDTreeToggle<cr>
" expand to the path of the file in the current buffer 
nmap <silent> <leader>y :NERDTreeFind<cr>  

" map fuzzyfinder (CtrlP) plugin
nmap <silent> <leader>t :CtrlP<cr>
nmap <silent> <leader>r :CtrlPBuffer<cr>

" CtrlP ignore patterns
let g:ctrlp_custom_ignore = '\.git$|\.hg$|\.svn$'

" Kwbd
nmap <leader>qq :Kwbd<cr>
