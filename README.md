# Dotfiles

These are my dotfiles, which contain my custom system configuration preferences. 

## Contents

+ zsh configuration
+ vim configuration
+ tmux configuration
+ git configuration
+ osx configuration
+ bash configuration

## Install

The organization of this project is similar to [Zach Holman's ](http://github.com/holman/dotfiles) setup.

### Automatic Installation

	wget 

### Manual Installation

#### Clone

First, clone the repository to your home directory and name it ".dotfiles"

	git clone git@github.com:nicknisi/dotfiles.git ~/.dotfiles

Then cd into that directory

	cd ~/.dotfiles

#### Init Submodules

The vim configuration relies on a couple of vim plugins, which are loaded in as git submodules.

	git submodule init
	git submodule update
	
#### Backup

A backup task is included. This will find all the files that will be replaced and make a backup of them. For example, if you currently have a ".zshrc" file, it will be moved to ".zshrc.backup"
	
	rake backup
	
#### Install

Symlink the necessary files. The task will perform a search  for all files in the *.dotfiles* directory that have the ".symlink" suffix and create a symbolic link in the home directory that drops the suffix and prefixes with a '.'

	rake install
	
## Uninstall

If you would like to bring back your previous configuration, run the uninstalll task. This will remove the created symlinks.

#### Uninstall

	rake uninstall
	
#### Restore
	
Then, if you would like to restore your previous configuration, run the restore task.
	
	rake restore
	
## ZSH Plugins

By default, the *.zshrc* file will source any file within .dotfiles that has the *".zsh"* suffix.