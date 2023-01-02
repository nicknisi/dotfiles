# use nvim, but don't make me think about it
if [[ -n "$(command -v nvim)" ]]; then
    alias vim="nvim"
    # shortcut to open vim and immediately update vim-plug and all installed plugins
    alias vimu="nvim --headless \"+Lazy! sync\" +qa"
    # immediately open to fugitive's status screen
    alias vimg="nvim +Ge:"
fi
