setlocal textwidth=0 wrapmargin=0 wrap spell
let g:markdown_fenced_languages = ['css', 'javascript', 'js=javascript', 'json=javascript', 'stylus', 'html']
autocmd BufNewFile,BufRead,BufWrite *.md syntax match Comment /\%^---\_.\{-}---$/
