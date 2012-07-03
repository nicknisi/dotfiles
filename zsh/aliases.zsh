# reload zsh config
alias reload!='source ~/.zshrc'

# Filesystem aliases
alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -lah'
alias la='ls -AF'
alias ll='ls -lFh'
alias lld='ls -l | grep ^d'
alias rmf='rm -rf'

# Helpers
alias grep='grep --color=auto'
alias df='df -h' # disk free, in Gigabytes, not bytes
alias du='du -h -c' # calculate disk usage for a folder

# rake fix
alias rake="noglob rake"

# Applications
alias mou='open -a Mou.app'
