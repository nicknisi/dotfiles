" load vim-plug if it does not exist in the dotfiles
let s:plugpath = expand('<sfile>:p:h') . '/plug.vim' " this is relative to this file, which is in autoload
function! functions#PlugLoad()
    if !filereadable(s:plugpath)
        if executable('curl')
            echom "Installing vim-plug at " . s:plugpath
            let plugurl = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
            call system('curl -fLo ' . shellescape(s:plugpath) . ' --create-dirs ' . plugurl)
            if v:shell_error
                echom "Error downloading vim-plug. Please install it manually.\n"
                exit
            endif
        else
            echom "vim-plug not installed. Please install it manually or install curl.\n"
            exit
        endif
    endif
endfunction

" Window movement shortcuts
" move to the window in the direction shown, or create a new window
function! functions#WinMove(key)
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

" smart tab completion
function! functions#Smart_TabComplete()
    let line = getline('.')                         " current line

    let substr = strpart(line, -1, col('.')+1)      " from the start of the current
    " line to one character right
    " of the cursor
    let substr = matchstr(substr, '[^ \t]*$')       " word till cursor
    if (strlen(substr)==0)                          " nothing to match on empty string
        return '\<tab>'
    endif
    let has_period = match(substr, '\.') != -1      " position of period, if any
    let has_slash = match(substr, '\/') != -1       " position of slash, if any
    if (!has_period && !has_slash)
        return '\<C-X>\<C-P>'                         " existing text matching
    elseif ( has_slash )
        return '\<C-X>\<C-F>'                         " file matching
    else
        return '\<C-X>\<C-O>'                         " plugin matching
    endif
endfunction

" execute a custom command
function! functions#RunCustomCommand()
    up
    if g:silent_custom_command
        execute 'silent !' . s:customcommand
    else
        execute '!' . s:customcommand
    endif
endfunction

function! functions#SetCustomCommand()
    let s:customcommand = input('Enter Custom Command$ ')
endfunction

function! functions#TrimWhiteSpace()
    %s/\s\+$//e
endfunction

function! functions#HtmlUnEscape()
  silent s/&lt;/</eg
  silent s/&gt;/>/eg
  silent s/&amp;/\&/eg
endfunction

" delete the current buffer
function! functions#Delete(...)
    if (exists('a:1'))
        let file=a:1
    elseif ( &ft == 'help' )
        echohl Error
        echo "Cannod delete a help buffer!"
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

function! functions#zoom()
  if winnr('$') > 1
    tab split
  elseif len(filter(map(range(tabpagenr('$')), 'tabpagebuflist(v:val + 1)'),
      \ 'index(v:val, '.bufnr('').') >= 0')) > 1
    tabclose
  endif
endfunction
