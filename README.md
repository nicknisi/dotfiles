# Dotfiles

Welcome to my world. This is a collection of vim, tmux, and zsh configurations.

## Contents

+ Initial setup
+ vim setup and neovim setup
+ zsh setup
+ tmux configuration
+ git configuration
+ OSX configuration
+ Homebrew
+ Node.js

## Initial setup and installation

If on OSX, you will need to install the XCode CLI tools before continuing. To do so, open a terminal and type

```bash
xcode-select --install
```

Then, clone the dotfiles repository to your computer. This can be placed anywhere, and symbolic links will be created to reference it from your home directory.

```bash
git clone https://github.com/nicknisi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

`install.sh` will start by initializing the submodules used by this repository. Then, it will install all symbolic links into your home directory. Every file with a `.symlink` extension will be symlinked to the home directory with a `.` in front of it. As an example, `vimrc.symlink` will be symlinked in the home directory as `~/.vimrc`. Then, this script will create a `~/.vim-tmp` directory in your home directory, as this is where vim is configured to 

Next, the isntall script will perform a check to see if it is running on an OSX machine. If so, it will install Homebrew if it is not currently installed and will install the homebrew packages listed in [`brew.sh`](install/brew.sh). Then, it will run [`installosx.sh`](installosx.sh) and change some OSX configurations. This file is pretty well documented and so it is advised that you __read through and comment out any changes you do not want__. Next, the script will call [`install/nvm.sh`](install/nvm.sh) to install Node.js (stable) using nvm.

## vim and neovim setup

vim and neovim should just work once the correct plugins are installed. To install the plugins, you will need to open vim/neovim in the following way:

for vim
```bash
vim +PlugInstall
```

for neovim
```bash
nvim +PlugInstall
```

### Fonts

I am currently using [Hack](http://sourcefoundry.org/hack/) as my default font, which does include Powerline support, so you don't need an additional patched font. In addition to this, I do have [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) installed and configured to be used for non-ascii characters. If you would prefer not to do this, then simply remove the `Plug 'ryanoasis/vim-devicons'` plugin from vim/nvim. Then, I configure the fonts in this way in iTerm2:

![](http://nicknisi.com/share/iterm-fonts-config.png)

-----

+ zsh configuration
+ vim configuration
+ tmux configuration
+ git configuration
+ osx configuration
+ Node.js setup (nvm)
+ Homebrew

## Install

1. `git clone https://github.com/nicknisi/dotfiles.git ~/.dotfiles`
1. `cd ~/.dotfiles`
1. `./install.sh`

## ZSH Plugins

By default, the `.zshrc` file will source any file within `.dotfiles/zsh` that have the `.zsh` extension.

## Vim Plugins

Vim plugins are managed with [vim-plug](https://github.com/junegunn/vim-plug). To install, run `vim +PlugInstall`.
