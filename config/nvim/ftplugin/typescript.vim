" Code Folding
syntax region foldBraces start=/{/ end=/}/ transparent fold keepend extend
setlocal foldmethod=syntax
setlocal foldlevel=99

" convert to object literal function syntax
let @f = "^f:dt("

" convert object literal anonymous function into class method syntax
let @c = "^f:dt(f{%f,x"

let g:tss_auto_open_loclist=1
nmap <buffer> <leader>h :TssQuickInfo<cr>
nmap <buffer> <leader>d :TssDefinition<cr>
nmap <buffer> <leader>u :TssReferences<cr>
nmap <buffer> <leader>e :TssErrors<cr>
nmap <buffer> <leader>m :TssRename "pc"<cr>
