" Zoom into a pane, making it full screen (in a tab)
" This plugin is useful when working with multiple panes
" but temporarily needing to zoom into one to see more of
" the code from that buffer.
" Triggering the plugin again from the zoomed in tab brings it back
" to its original pane location
function s:Zoom()
    if winnr('$') > 1
        tab split
    elseif len(filter(map(range(tabpagenr('$')), 'tabpagebuflist(v:val + 1)'),
        \ 'index(v:val, ' . bufnr('') . ') >= 0')) > 1
        tabclose
    endif
endfunction

nnoremap <Plug>Zoom :<C-U>call <SID>Zoom()<cr>
