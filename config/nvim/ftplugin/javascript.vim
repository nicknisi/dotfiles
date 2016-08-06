setlocal textwidth=120

let g:neomake_javascript_enabled_markers = findfile('.jshintrc', '.;') != '' ? ['jshint'] : ['eslint']
