let s:goyo_entered = 0
function! helpers#goyo#enter()
    silent !tmux set status off
    let s:goyo_entered = 1
    set noshowmode
    set noshowcmd
    set scrolloff=999
    set wrap
    setlocal textwidth=0
    setlocal wrapmargin=0
endfunction

function! helpers#goyo#leave()
    silent !tmux set status on
    let s:goyo_entered = 0
    set showmode
    set showcmd
    set scrolloff=5
    set textwidth=120
    set wrapmargin=8
endfunction

