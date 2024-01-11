# reload zsh config
alias reload!='RELOAD=1 source ~/.zshrc'

# Filesystem aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Helpers
alias grep='grep --color=auto'
alias df='df -h' # disk free, in Gigabytes, not bytes
alias du='du -h -c' # calculate disk usage for a folder

alias lpath='echo $PATH | tr ":" "\n"' # list the PATH separated by new lines

# Applications
alias ios='open -a /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"
# remove broken symlinks
alias clsym="find -L . -name . -o -type d -prune -o -type l -exec rm {} +"


# use exa if available
if [[ -x "$(command -v exa)" ]]; then
  alias ll="exa --icons --git --long"
  alias l="exa --icons --git --all --long"
else
  alias l="ls -lah ${colorflag}"
  alias ll="ls -lFh ${colorflag}"
fi
alias la="ls -AF ${colorflag}"
alias lld="ls -l | grep ^d"
alias rmf="rm -rf"

# Fyma aliases
export FYMA_PATH="~/code/fyma"

alias fca="cd $FYMA_PATH/core-api-v2"
alias fba="cd $FYMA_PATH/browser-app-v2"
alias fk8s="cd $FYMA_PATH/k8s"
alias fk="cd $FYMA_PATH/k8s"

alias fgauth="gcloud auth login --no-browser"
alias fgcred="gcloud container clusters get-credentials cluster --zone europe-west3-b --project fyma-platform"

alias get

# SS aliases
export SS_PATH="~/code/ss"

alias ss="cd $SS_PATH"
alias sa="cd $SS_PATH/app"

# Git aliases

alias gst="git status"
alias gco="git checkout"
