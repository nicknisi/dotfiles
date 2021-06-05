let javaScript_fold=1

" nvim-typescript helper mappings
nmap <silent> <leader>d :TSDef<cr>
nmap <silent> <leader>u :TSRefs<cr>
nmap <silent> <leader>h :TSType<cr>

setl omnifunc=TSOmnicFunc

nmap <leader>x :call VimuxRunCommand('npm test')<cr>
