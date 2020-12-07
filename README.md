# Disclaimer

I forked to use for my own usage.

## Initial Setup and Installation

### Backup

This version doesn't have backup your original dotfiles. Please use with your own risk.

### Installation

If on OSX, you will need to install the XCode CLI tools before continuing. To do so, open a terminal and type

```bash
➜ xcode-select --install
```

Then, clone the dotfiles repository to your home directory as `~/.dotfiles`. 

```bash
➜ git clone https://github.com/chiendo97/dotfiles.git ~/.dotfiles
➜ cd ~/.dotfiles
➜ ./install.sh
```

`install.sh` will start with helps

    homebrew: install homebrew dependencies

    shell: install zimfw and p10k

    terminfo: support italic fonts in and out of tmux

    macos: modify macos setting

    sync_dotfiles: sync the current dotfiles back to this repo

    all: setup all
        setup_terminfo
        setup_homebrew
        setup_shell
        setup_macos


## Terminal Capabilities

In order to properly support italic fonts in and out of tmux, a couple of terminal capabilities need to be described. Run the following from the root of the project:

```bash
tic -x resources/xterm-256color-italic.terminfo
tic -x resources/tmux.terminfo
```

## ZSH Setup

* Install zimfw
* Install p10k
* And more...

## Neovim Setup

### Installation

## Fonts

I am currently using Hack Nerd Font

## Tmux Configuration

