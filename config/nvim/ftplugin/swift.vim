let g:neomake_swift_swift_maker = {
        \ 'args': [ 'build' ],
        \ 'append_file': 0,
        \ 'errorformat':
        \    '%E%f:%l:%c: error: %m,' .
        \    '%W%f:%l:%c: warning: %m,' .
        \    '%Z%\s%#^~%#,' .
        \    '%-G%.%#',
        \ }

let g:neomake_swift_swiftc_maker = {
        \ 'args': [ '-parse' ],
        \ 'errorformat':
        \    '%E%f:%l:%c: error: %m,' .
        \    '%W%f:%l:%c: warning: %m,' .
        \    '%Z%\s%#^~%#,' .
        \    '%-G%.%#',
        \ }

let g:neomake_swift_enabled_makers = ['swift']
