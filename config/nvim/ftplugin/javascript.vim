setlocal textwidth=120

let g:jsx_ext_required = 0
let g:javascript_plugin_jsdoc = 1

" Code Folding
syntax region foldBraces start=/{/ end=/}/ transparent fold keepend extend
" setlocal foldmethod=syntax
setlocal foldlevel=99

" vim-tss settings - useful when a jsconfig.json file exists in the project root
let g:tss_auto_open_loclist=1
nmap <buffer> <leader>h :TssQuickInfo<cr>
nmap <buffer> <leader>d :TssDefinition<cr>
nmap <buffer> <leader>u :TssReferences<cr>
nmap <buffer> <leader>e :TssErrors<cr>
nmap <buffer> <leader>m :TssRename "pc"<cr>
