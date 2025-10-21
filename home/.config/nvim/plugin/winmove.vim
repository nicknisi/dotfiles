" Window movement shortcuts
" move to the window in the direction shown, or create a new window
function s:WinMove(key)
    let t:curwin = winnr()
    exec "wincmd ".a:key
    if (t:curwin == winnr())
        if (match(a:key,'[jk]'))
            wincmd v
        else
            wincmd s
        endif
        exec "wincmd ".a:key
    endif
endfunction

" Navigate to pane to the left, or create a new pane
nnoremap <Plug>WinMoveLeft :<C-U>call <SID>WinMove('h')<CR>
" Navigate to pane to below, or create a new pane
nnoremap <Plug>WinMoveDown :<C-U>call <SID>WinMove('j')<CR>
" Navigate to pane above, or create a new pane
nnoremap <Plug>WinMoveUp :<C-U>call <SID>WinMove('k')<CR>
" Navigate to pane to the right, or create a new pane
nnoremap <Plug>WinMoveRight :<C-U>call <SID>WinMove('l')<CR>
