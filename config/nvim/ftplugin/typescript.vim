let javaScript_fold=1

" TypeScript Options
let g:tsuquyomi_completion_detail = 1
let g:tsuquyomi_disable_default_mappings = 1
" setlocal completeopt+=menu,preview
let g:tsuquyomi_completion_detail = 1
setlocal completeopt=menuone,noselect,noselect
setlocal omnifunc=tsuquyomi#complete 
nmap <silent> <leader>d :TsuDefinition<cr>
nmap <silent> <leader>u :TsuReferences<cr>
nmap <silent> <leader>e :TsuGeterr<cr>
nmap <buffer> <Leader>h : <C-u>echo tsuquyomi#hint()<CR>
