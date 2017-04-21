setlocal textwidth=120

let g:neomake_javascript_enabled_makers = filereadable('.jshintrc') ? ['jshint'] : ['eslint']
let g:jsx_ext_required = 0
let g:javascript_plugin_jsdoc = 1

let g:neomake_javascript_jshint_exe = 'npm-exec'
let g:neomake_javascript_jshint_args = ['jshint', '--verbose']
let g:neomake_javascript_eslint_exe = 'npm-exec'
let g:neomake_javascript_eslint_args = ['eslint', '-f', 'compact']

" Code Folding
syntax region foldBraces start=/{/ end=/}/ transparent fold keepend extend
" setlocal foldmethod=syntax
setlocal foldlevel=99
