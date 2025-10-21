" delete the current buffer
function! functions#Delete(...)
    if (exists('a:1'))
        let file=a:1
    elseif ( &ft == 'help' )
        echohl Error
        echo "Cannot delete a help buffer!"
        echohl None
        return -1
    else
        let file=expand('%:p')
    endif
    let status=delete(file)
    if (status == 0)
        echo "Deleted " . file
    else
        echohl WarningMsg
        echo "Failed to delete " . file
        echohl None
    endif
    return status
endfunction
