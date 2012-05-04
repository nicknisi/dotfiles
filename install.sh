#!/bin/sh

# clone the repository
git clone git@github.com:nicknisi/dotfiles.git ~/.dotfiles

# cd into directory
cd ~/.dotfiles

# initialize submodules
git submodule init
git submodule update

# backup existing configuration
rake backup

# run the install
rake install
