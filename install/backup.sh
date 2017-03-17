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
        mv -f $target $BACKUP_DIR
    else
        echo -e "$filename does not exist at this location"
    fi
done

files=("$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc")
for filename in "$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc"; do
    if [[ -f "$filename"  || -L "$filename" ]]; then
        echo "backing up $filename"
        mv $filename $BACKUP_DIR
    elif [ -e $filename ]; then
        echo "backing up $filename"
        cp -r $filename $BACKUP_DIR
    rm -rf $filename
    else
        echo -e "$filename does not exist at this location"
    fi
done
