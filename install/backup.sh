#!/usr/bin/env bash

# Backup files that are provided by the dotfiles into a ~/dotfiles-backup directory

DOTFILES=$HOME/.dotfiles
BACKUP_DIR=$HOME/dotfiles-backup

set -e # TODO: what does this do?

echo "Creating backup directory at $BACKUP_DIR"
mkdir -p $BACKUP_DIR

linkables=$( find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' )

for file in $linkables; do
    filename=".$( basename $file '.symlink' )"
    target="$HOME/$filename"
    if [ -f $target ]; then
        echo "backing up $filename"
        cp $target $BACKUP_DIR
    else
        echo -e "$filename does not exist at this location or is a symlink"
    fi
done

files=("$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc")
for filename in "$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc"; do
    if [ ! -L $filename ]; then
        echo "backing up $filename"
        cp -rf $filename $BACKUP_DIR
    else
        echo -e "$filename does not exist at this location or is a symlink"
    fi
done
