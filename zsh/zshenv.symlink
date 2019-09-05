export DOTFILES=$HOME/.dotfiles
export CACHEDIR="$HOME/.local/share"

[[ -d "$CACHEDIR" ]] || mkdir -p "$CAHCEDIR"

fpath=(
    $DOTFILES/zsh/functions
    /usr/local/share/zsh/site-functions
    $fpath
)

typeset -aU path

export EDITOR='nvim'
export GIT_EDITOR='nvim'
