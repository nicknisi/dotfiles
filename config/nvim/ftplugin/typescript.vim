let javaScript_fold=1

setlocal completeopt=menuone,noselect,noselect
setlocal omnifunc=tsuquyomi#complete 
nmap <silent> <leader>d :TsuDefinition<cr>
nmap <silent> <leader>u :TsuReferences<cr>
nmap <silent> <leader>e :TsuGeterr<cr>
nmap <buffer> <Leader>h : <C-u>echo tsuquyomi#hint()<CR>
