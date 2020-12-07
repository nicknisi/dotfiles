# === Start configuration added by Zim install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}


# --------------------
# Module configuration
# --------------------

#
# completion
#

# Set a custom path for the completion dump file.
# If none is provided, the default ${ZDOTDIR:-${HOME}}/.zcompdump is used.
#zstyle ':zim:completion' dumpfile "${ZDOTDIR:-${HOME}}/.zcompdump-${ZSH_VERSION}"

#
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=10'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=10'

# ------------------
# Initialize modules
# ------------------

if [[ ${ZIM_HOME}/init.zsh -ot ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  # Update static initialization script if it's outdated, before sourcing it
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
source ${ZIM_HOME}/init.zsh

# ------------------------------
# Post-init module configuration
# ------------------------------

#
# zsh-history-substring-search
#

# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Bind up and down keys
zmodload -F zsh/terminfo +p:terminfo
if [[ -n ${terminfo[kcuu1]} && -n ${terminfo[kcud1]} ]]; then
  bindkey ${terminfo[kcuu1]} history-substring-search-up
  bindkey ${terminfo[kcud1]} history-substring-search-down
fi

bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
# }}} End configuration added by Zim install

# {{{ === ALIAS
alias t="tree -a -I '.git'"
alias c='clear'
alias v='vim' # quick opening files with vim
alias n='nvim' # quick opening files with vim

alias tx='tmux'
alias nv='nvim'
alias gf='git fetch --all'
alias gd='git diff'
alias gb='git branch'
alias gs='git status'
alias gl='git log'

alias pys='source env/bin/activate'
alias pyd='deactivate'

alias gst='git stash'
alias gsp='git stash pop'

alias dt='/usr/bin/git --git-dir=$HOME/.dotfiles/.git/ --work-tree=$HOME' # dotfiles for .files config
alias cpwd="pwd | tr -d '\n' | pbcopy" # Copy pwd to clipboard

alias mci='mvn clean install'
alias mcp='mvn clean package'
# }}}

# {{{ === PATH
export fpath=(/usr/local/share/zsh-completions $fpath)

export PATH="$HOME/.yarn/bin:$PATH"
export PATH="$HOME/.config/yarn/global/node_modules/.bin:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/opt/gettext/bin:$PATH"
export PATH="/usr/local/bin/:$PATH"

export HADOOP_HOME=/usr/local/Cellar/hadoop/3.2.1/libexec/
export HADOOP_VERSION=3.2.1
# }}}

# {{{ === SETTING
# Allows ‘>’ redirection to truncate existing files. EX: pbpaste > file.txt
setopt clobber

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export EDITOR=/usr/local/bin/nvim

export DOCKER_HOST_IP=127.0.0.1
# }}}

# {{{ === MAPPING KEY 
bindkey -e # use like emacs editor
bindkey '^p' up-history
bindkey '^n' down-history
bindkey '^r' history-incremental-search-backward

autoload -U edit-command-line
zle -N edit-command-line
bindkey '^f' edit-command-line
# }}}

# {{{ === SOURCE 
source /usr/local/Cellar/fzf/0.24.4/shell/completion.zsh
source /usr/local/Cellar/fzf/0.24.4/shell/key-bindings.zsh
# }}}

# {{{ === GO DEV
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export GO111MODULE=auto
export GOPROXY=direct
export GOSUMDB=off
export GOPRIVATE=git.garena.com/*

export SP_UNIX_SOCKET=~/run/spex/spex.sock

export PATH=$GOPATH/bin:$PATH
# }}}

# {{{ === FASD INIT ===
eval "$(fasd --init auto)"
# }}}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
