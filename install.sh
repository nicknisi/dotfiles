#!/bin/bash

echo "installing dotfiles"

echo "initializing submodule(s)"
git submodule update --init --recursive

source install/link.sh

if [ "$(uname)" == "Darwin" ]; then
    echo "running on OSX"

    echo "installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

    echo "brewing all the things"
    source scripts/brew.sh

    echo "updating OSX settings"
    source scripts/osx.sh

    echo "installing node (from nvm)"
    nvm install stable
    nvm alias default stable
fi


echo "configuring zsh as default shell"
chsh -s $(which zsh)
