#!/bin/sh

zplug 'zplug/zplug', hook-build:'zplug --self-manage'
zplug 'zsh-users/zsh-syntax-highlighting', defer:2
zplug 'zsh-users/zsh-autosuggestions'
zplug 'akoenig/npm-run.plugin.zsh'
zplug 'yonchu/grunt-zsh-completion'

# export NVM_LAZY_LOAD=true
# export NVM_NO_USE=true
zplug "lukechilds/zsh-nvm"

# Install plugins if there are plugins that have not been installed
if ! zplug check; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

zplug load
