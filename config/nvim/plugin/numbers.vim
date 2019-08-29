let s:regNums = ['0b[01]', '0x\x', '\d' ]

" select the next number on the line
" this can handle the following three formats:
"     1. binary  (eg: '0b1010', '0b0000', etc)
"     2. hex     (eg: '0xffff', '0x0000', etc)
"     3. decimal (eg: '0', '10', '01', etc)
function! s:InNumber()
    " magic is required
    let l:magic = &magic
    set magic

    let l:lineNr = line('.')

    " create regex pattern matching any binary, hex, decimal number
    let l:pat  = join(s:regNums, '\+\|') . '\+'

    " move cursor to the end of number
    if (!search(l:pat, 'ce', l:lineNr))
        " if it fails, there was no match on this line
        return
    endif

    " start visually selecting
    normal! v

    " move cursor to beginning of the number
    call search(l:pat, 'cb', l:lineNr)

    " restore magic
    let &magic = l:magic
endfunction

" 'in number' (next number after cursor on current line)
xnoremap <silent> in :<c-u>call <sid>InNumber()<cr>
onoremap <silent> in :<c-u>call <sid>InNumber()<cr>

function! s:AroundNumber()
    " select the next number on the line and any surrounding white-space;
    " this can handle the following three formats (so long as s:regNums is
    " defined as it should be above these functions):
    "   1. binary  (eg: "0b1010", "0b0000", etc)
    "   2. hex     (eg: "0xffff", "0x0000", "0x10af", etc)
    "   3. decimal (eg: "0", "0000", "10", "01", etc)
    " NOTE: if there is no number on the rest of the line starting at the
    "       current cursor position, then visual selection mode is ended (if
    "       called via an omap) or nothing is selected (if called via xmap);
    "       this is true even if on the space following a number

    " need magic for this to work properly
    let l:magic = &magic
    set magic

    let l:lineNr = line('.')

    " create regex pattern matching any binary, hex, decimal number
    let l:pat = join(s:regNums, '\+\|') . '\+'

    " move cursor to end of number
    if (!search(l:pat, 'ce', l:lineNr))
        " if it fails, there was not match on the line, so return prematurely
        return
    endif

    " move cursor to end of any trailing white-space (if there is any)
    call search('\%'.(virtcol('.')+1).'v\s*', 'ce', l:lineNr)

    " start visually selecting from end of number + potential trailing whitspace
    normal! v

    " move cursor to beginning of number
    call search(l:pat, 'cb', l:lineNr)

    " move cursor to beginning of any white-space preceding number (if any)
    call search('\s*\%'.virtcol('.').'v', 'b', l:lineNr)

    " restore magic
    let &magic = l:magic
endfunction

" 'around number' (next number on line and possible surrounding white-space)
xnoremap <silent> an :<c-u>call <sid>AroundNumber()<cr>
onoremap <silent> an :<c-u>call <sid>AroundNumber()<cr>

