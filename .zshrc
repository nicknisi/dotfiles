# {{{ === ALIAS
alias l="exa"
alias t="tree -a -I '.git'"
alias c='clear'
alias v='vim'  # quick opening files with vim
alias n='nvim' # quick opening files with vim

alias gi='git'
alias tx='tmux'
alias nv='nvim'
alias gf='git fetch --all'
alias gd='git diff'
alias gb='git branch'
alias gs='git status'
alias gl='git log'

alias cpwd="pwd | tr -d '\n' | pbcopy" # Copy pwd to clipboard

alias pp='go tool pprof'
# }}}

# {{{ === PATH
# export fpath=(/usr/local/share/zsh-completions $fpath)

export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin/:$PATH"
export PATH="$HOME/Library/Python/2.7/bin:$PATH"
export PATH="/usr/local/opt/llvm/bin:$PATH"
# }}}

# {{{ === SETTING

# Allows ‘>’ redirection to truncate existing files. EX: pbpaste > file.txt
setopt clobber
setopt glob_complete
setopt inc_append_history
setopt hist_ignore_dups
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_expire_dups_first
setopt hist_ignore_space
setopt share_history

# export LC_ALL=en_US.UTF-8
# export LANG=en_US.UTF-8
# export LANGUAGE=en_US.UTF-8
# export EDITOR='/usr/local/bin/nvim -u NONE'
# export DOCKER_HOST_IP=127.0.0.1

# }}}

# {{{ === MAPPING KEY
bindkey -e # use like emacs editor
bindkey '^p' up-history
bindkey '^n' down-history
bindkey '^r' history-incremental-search-backward

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^g' edit-command-line
# }}}

# {{{ === GO DEV
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export GO111MODULE=auto
export GOSUMDB=off
export GOPRIVATE=git.garena.com/*

export SP_UNIX_SOCKET=~/run/spex/spex.sock

export PATH=$GOPATH/bin:$PATH
# }}}

# {{{ === FASD INIT ===
eval "$(fasd --init auto)"
# }}}

alias luamake=/Users/chien.le/.config/nvim/lua-language-server/3rd/luamake/luamake
# if [ /usr/local/bin//kubectl ]; then source <(kubectl completion zsh); fi

[ -d "$HOME/Library/Android/sdk" ] && ANDROID_SDK=$HOME/Library/Android/sdk || ANDROID_SDK=$HOME/Android/Sdk
echo "export ANDROID_SDK=$ANDROID_SDK" >>~/$([[ $SHELL == *"zsh" ]] && echo '.zshenv' || echo '.bash_profile')

export PATH=/Users/chien.le/Library/Android/sdk/platform-tools:$PATH

# fzf init setup
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

autoload -U promptinit
promptinit
prompt pure

# fbr - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
gco() {
	local branches branch
	branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
		branch=$(echo "$branches" | fzf-tmux -h $((2 + $(wc -l <<<"$branches"))) +m) &&
		git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

autoload -Uz compinit
if [ $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]; then
	compinit
else
	compinit -C
fi
