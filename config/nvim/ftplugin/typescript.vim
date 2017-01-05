let g:neomake_typescript_tsc_maker = {
    \ 'args': [ '-m', 'commonjs', '--noEmit' ],
    \ 'append_file': 0,
    \ 'errorformat':
            \ '%E%f %#(%l\,%c): error %m,' .
            \ '%E%f %#(%l\,%c): %m,' .
            \ '%Eerror %m,' .
            \ '%C%\s%\+%m'
\ }

" convert to object literal function syntax
let @f = "^f:dt("

" convert object literal anonymous function into class method syntax
let @c = "^f:dt(f{%f,x"
