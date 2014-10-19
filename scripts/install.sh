echo "cloning repo to ~/.dotfiles"
git clone git@github.com:nicknisi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
echo "initializing git submodules"
git submodule init
git submodule update
echo "running backup"
rake backup
echo "creating symlinks"
rake install
