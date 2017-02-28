setlocal textwidth=120

let g:neomake_javascript_enabled_markers = findfile('.jshintrc', '.;') != '' ? ['jshint'] : ['eslint']

" Code Folding
syntax region foldBraces start=/{/ end=/}/ transparent fold keepend extend
setlocal foldmethod=syntax
setlocal foldlevel=99
