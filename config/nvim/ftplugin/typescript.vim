let javaScript_fold=1

" nvim-typescript helper mappings
nmap <silent> <leader>d :TSDef<cr>
nmap <silent> <leader>u :TSRefs<cr>
nmap <silent> <leader>h :TSType<cr>
nmap K :TSDoc<cr>

setl omnifunc=TSOmnicFunc

nmap <leader>x :VimuxRunCommand('npm test')<cr>
