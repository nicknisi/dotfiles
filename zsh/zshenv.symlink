export DOTFILES="$HOME/.dotfiles"
export CACHEDIR="$HOME/.local/share"
export VIM_TMP="$HOME/.vim-tmp"

[[ -d "$CACHEDIR" ]] || mkdir -p "$CACHEDIR"
[[ -d "$VIM_TMP" ]] || mkdir -p "$VIM_TMP"

fpath=(
    $DOTFILES/zsh/functions
    /usr/local/share/zsh/site-functions
    $fpath
)

typeset -aU path

export EDITOR='nvim'
export GIT_EDITOR='nvim'
