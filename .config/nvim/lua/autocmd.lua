local exec = vim.api.nvim_exec -- execute Vimscript

exec([[
if has("autocmd")
  " Auto disable syntax with large file
  augroup syntaxoff
    autocmd!
    autocmd Filetype * if getfsize(expand("%")) > 100000 | setlocal syntax=OFF | endif
  augroup END

  " Back to line
  augroup line
    autocmd!
    au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
  augroup END

  " Auto disable folding with large file
  augroup fold
    autocmd!
    autocmd FileType * if getfsize(expand("%")) < 100000 | setlocal foldmethod=marker foldlevel=0 | endif 
    autocmd FileType go if getfsize(expand("%")) < 10000 | setlocal foldmethod=syntax foldlevel=20 | endif 
  augroup END

  " Syntax of these languages is fussy over tabs Vs spaces
  augroup filetype
    autocmd!
    autocmd FileType make       setlocal ts=8 sts=8 sw=8 noexpandtab
    autocmd FileType yaml       setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType html       setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType css        setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType typescript setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType javascript setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType json       setlocal ts=4 sts=4 sw=4 expandtab
    autocmd FileType cpp        setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
    autocmd FileType go         setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
    autocmd FileType php        setlocal ts=4 sts=4 sw=4 expandtab smarttab
    autocmd FileType vim        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType sh         setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType zsh        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType lua        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType sql        setlocal ts=4 sts=4 sw=4 expandtab smarttab
    autocmd FileType xml        setlocal ts=2 sts=2 sw=2 expandtab smarttab
    autocmd FileType proto      setlocal ts=4 sts=4 sw=4 noexpandtab smarttab
    autocmd FileType typescriptreact setlocal ts=2 sts=2 sw=2 expandtab
    autocmd FileType javascriptreact setlocal ts=2 sts=2 sw=2 expandtab
  augroup END

endif
]], false)
