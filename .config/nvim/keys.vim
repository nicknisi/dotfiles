
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mapping:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let mapleader = " "


"{{{ === Debug

command! Run set splitright | vnew | set filetype=sh | read !sh #

" command!      -bang -nargs=* Debug                   call s:debug(<q-args>, <bang>0, <bang>0)'])
" function! s:debug(arg, extra, bang)
"   echom a:arg
"   echom a:extra
"   echom a:bang
" endfunction

nnoremap <M-A> :echo "TEST"<CR>

nnoremap <silent> <leader>D :call <SID>Debug()<CR>
function! s:Debug()
  echo mode()
endfunction
nnoremap <leader>D :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
\ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
\ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>
"}}}

" {{{ === Align
xmap ga <Plug>(EasyAlign)| " Start interactive EasyAlign in visual mode (e.g. vipga)
" }}}

" {{{ === Line navigation
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv
" ^ - jump to the first non-blank character of the line
nnoremap H ^
vnoremap H ^
" g_ - jump to the end of the line
nnoremap L g_
vnoremap L g_
" }}}

" {{{ === Highlight
nnoremap <silent> * :let @/ = '\<'.expand('<cword>').'\>'\|set hlsearch<C-M>
nmap <silent> <C-C> :noh<CR><esc>
imap <silent> <C-C> <esc><C-C>
vmap <silent> <C-C> <esc><C-C>

vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>
" }}}

" {{{ === Rg
nnoremap <silent> <leader>R :call <SID>RgCurrentWord()<CR>
function! s:RgCurrentWord()
    let @/ = ''
    let wordUnderCursor = expand("<cword>")
    execute 'Rg '. wordUnderCursor
endfunction

vnoremap <silent> <leader>R :call <SID>RgCurrentSelected()<CR>
function! s:RgCurrentSelected()
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  let currentSelected = join(lines, "\n")
  execute 'Rg '. currentSelected
endfunction
" }}}

" {{{ === Git
nnoremap <leader>b :<C-U>Gblame<cr>|    " Open git blame for current file"
nmap ]h <Plug>(GitGutterNextHunk)
nmap [h <Plug>(GitGutterPrevHunk)
nmap ghs <Plug>(GitGutterStageHunk)
nmap ghu <Plug>(GitGutterUndoHunk)
nmap ghp <Plug>(GitGutterPreviewHunk)
" }}}

"{{{ === NERDCommenter
nmap <C-_> <plug>NERDCommenterToggle| " map <C-/> to use toggle comment
vmap <C-_> <plug>NERDCommenterToggle| " map <C-/> to use toggle comment
"}}}

"{{{ === Fuzzy search
nnoremap <leader>g :GFiles<cr>|          " fuzzy find files under version control in the working directory (where you launched Vim from)"
nnoremap <leader>f :Files<cr>|           " fuzzy find files in the working directory (where you launched Vim from)
nnoremap <leader>r :Rg |                 " fuzzy find text in the working directory
nnoremap <leader>h :History<cr>|         " fuzzy find files from most recent files
nnoremap <leader>m :Maps<cr>|            " fuzzy find key mappings
nnoremap <leader>H :Helptags!<cr>|       " fuzzy find documentation
nnoremap <leader>C :<C-U>Commands!<cr>|  " fuzzy find documentation
nnoremap <leader>l :<C-U>Lines<cr>|      " fuzzy find line
"}}}

"{{{ === Tab navigation
nnoremap <silent> gt :tabedit<CR>
nnoremap <silent> g1 1gt
nnoremap <silent> g2 2gt
nnoremap <silent> g3 3gt
nnoremap <silent> g4 4gt
nnoremap <silent> g5 5gt
nnoremap <silent> g6 6gt
nnoremap <silent> g7 7gt
nnoremap <silent> g8 8gt
nnoremap <silent> g9 9gt
"}}}

"{{{ === Motions
nnoremap <silent> j gj| " Move down to wrap line
nnoremap <silent> k gk| " Move up to wrap line
"}}}

"{{{ === Yank
" Note: some register location
" 0 - the last yank
" " - the last delete
" / - the last search
" * - the system clipboard (most of the time)
" - - blackhole

vnoremap y "*y| " Copy to clipboard
vnoremap p "*p| " Paste from clipboard

" Copy (current path + current line number) to clipboard
nnoremap <leader>yp :let @* = expand("%") . ":" . line(".")<CR>
nnoremap <leader>yP :let @* = expand("%:p") . ":" . line(".")<CR>

" Copy (current path + current line number + current line) to clipboard
nnoremap <silent><leader>Fp :norm yy<CR>:let @* = expand("%") . ":" . line(".") . ":" . @"<CR>
nnoremap <silent><leader>FP :norm yy<CR>:let @* = expand("%:p") . ":" . line(".") . ":" . @"<CR>
"}}}

"{{{ === Coc

let g:coc_snippet_next = '<tab>'
let g:coc_snippet_prev = '<s-tab>'

" Open coc-explorer
nnoremap <silent><leader>c :CocCommand explorer<CR>

" Use `[c` and `]c` for navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Go to the first floating window
nmap <silent> <C-f> <Plug>(coc-float-jump)

" Use K for show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

nmap <leader>en <Plug>(coc-rename)|                           " Remap for rename current word

" Using CocList
nnoremap <silent> <leader>ia  :<C-u>CocList diagnostics<cr>|  " Show all diagnostics
nnoremap <silent> <leader>ie  :<C-u>CocList extensions<cr>|   " Manage extensions
nnoremap <silent> <leader>il  :<C-u>CocList<CR>|              " Open coc list
nnoremap <silent> <leader>ic  :<C-u>CocList commands<CR>|     " Open coc commands

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocAction('format')

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')
"}}}

"{{{ === Autocomplete

if exists('*complete_info')
  inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
else
  inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
endif

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()
"}}}

"{{{ === Config files
nnoremap <Leader>ev :<C-u>e $MYVIMRC<CR>|                  " quick edit vimrc
nnoremap <Leader>sv :<C-u>source $MYVIMRC<CR>|             " quick source vimrc (after edit normally)
nnoremap <Leader>ec :<C-u>CocConfig<CR>|                   " quick edit coc config
"}}}

""{{{ === Visual recent pasted code
nnoremap gV `[v`]
"}}}

"{{{ === Folding
nnoremap <leader><space> za   " Open and close folds
"}}}
