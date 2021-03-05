#!/usr/bin/env bash

DOTFILES="$(pwd)"
COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"

title() {
    echo -e "\n${COLOR_PURPLE}$1${COLOR_NONE}"
    echo -e "${COLOR_GRAY}==============================${COLOR_NONE}\n"
}

error() {
    echo -e "${COLOR_RED}Error: ${COLOR_NONE}$1"
    exit 1
}

warning() {
    echo -e "${COLOR_YELLOW}Warning: ${COLOR_NONE}$1"
}

info() {
    echo -e "${COLOR_BLUE}Info: ${COLOR_NONE}$1"
}

success() {
    echo -e "${COLOR_GREEN}$1${COLOR_NONE}"
}

sync_dotfiles() {
    title "Sync dotfiles"

    info "Tmux"
    cp -r "$DOTFILES/.tmux.conf" ~/.tmux.conf

    info "Alacritty"
    cp -r "$DOTFILES/.config/alacritty/" ~/.config/alacritty/

    info "Neovim"
    cp -r "$DOTFILES/.config/nvim/" ~/.config/nvim/

    info "Shell"
    cp -r "$DOTFILES/.p10k.zsh" ~/.p10k.zsh
    cp -r "$DOTFILES/.zimrc" ~/.zimrc
    cp -r "$DOTFILES/.zshrc" ~/.zshrc

    info "Gitdotfiles"
    cp -r "$DOTFILES/.gitconfig" ~/.gitconfig
    cp -r "$DOTFILES/.gitignore_global" ~/.gitignore_global
}


update_dotfiles() {
    title "Update dotfiles"

    info "Tmux"
    cp -r ~/.tmux.conf "$DOTFILES/.tmux.conf"

    info "Alacritty"
    mkdir -p "$DOTFILES/.config/alacritty/"
    cp -r ~/.config/alacritty/ "$DOTFILES/.config/alacritty/"

    info "Neovim"
    mkdir -p "$DOTFILES/.config/nvim/"
    cp -r ~/.config/nvim/ "$DOTFILES/.config/nvim/"

    info "Shell"
    cp -r ~/.p10k.zsh "$DOTFILES/.p10k.zsh"
    cp -r ~/.tmux.conf "$DOTFILES/.tmux.conf"
    cp -r ~/.zimrc "$DOTFILES/.zimrc"
    cp -r ~/.zshrc "$DOTFILES/.zshrc"

    info "Gitdotfiles"
    cp -r ~/.gitconfig "$DOTFILES/.gitconfig"
    cp -r ~/.gitignore_global "$DOTFILES/.gitignore_global"
}

setup_homebrew() {
    title "Setting up Homebrew"

    if test ! "$(command -v brew)"; then
        info "Homebrew not installed. Installing."
        # Run as a login shell (non-interactive) so that the script doesn't pause for user input
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login
    fi

    # install brew dependencies from Brewfile
    brew bundle

    # install fzf
    echo -e
    info "Installing fzf"
    "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

function setup_shell() {
    title "Configuring shell"

    info "Setup zimfw"
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh

    info "setup p10k"
    cp .zimrc ~/
    zimfw install

    cp .zshrc ~/
}

function setup_tmux() {
    title "Configuring tmux"

    info "tmux package manager"
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

    cp .tmux.conf ~/
}

function setup_neovim() {
    title "Configuring neovim"

    mkdir -p ~/.config/nvim
    cp -r .config/nvim/ ~/.config/nvim/

    info "Run nvim +PlugInstall to install plugins"
}

function setup_alacritty() {
    title "Configuring alacritty"

    mkdir -p ~/.config/alacritty
    cp -r .config/alacritty/ ~/.config/alacritty/
}

function setup_terminfo() {
    title "Configuring terminfo"

    info "adding tmux.terminfo"
    tic -x "$DOTFILES/resources/tmux.terminfo"

    info "adding xterm-256color-italic.terminfo"
    tic -x "$DOTFILES/resources/xterm-256color-italic.terminfo"
}

setup_macos() {
    title "Configuring macOS"
    if [[ "$(uname)" == "Darwin" ]]; then

        echo "Finder: show all filename extensions"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true

        echo "Use current directory as default search scope in Finder"
        defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

        echo "Show Path bar in Finder"
        defaults write com.apple.finder ShowPathbar -bool true

        echo "Show Status bar in Finder"
        defaults write com.apple.finder ShowStatusBar -bool true

        echo "Disable press-and-hold for keys in favor of key repeat"
        defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

        echo "Kill affected applications"

        for app in Safari Finder Dock Mail SystemUIServer; do killall "$app" >/dev/null 2>&1; done
    else
        warning "macOS not detected. Skipping."
    fi
}

case "$1" in
    homebrew)
        setup_homebrew
        ;;
    shell)
        setup_shell
        ;;
    terminfo)
        setup_terminfo
        ;;
    macos)
        setup_macos
        ;;
    alacritty)
        setup_alacritty
        ;;
    neovim)
        setup_neovim
        ;;
    sync)
        sync_dotfiles
        ;;
    update)
        update_dotfiles
        ;;
    all)
        setup_terminfo
        setup_homebrew
        setup_alacritty
        setup_neovim
        setup_shell
        setup_macos
        ;;
    *)
        echo -e $"\nUsage: $(basename "$0") {homebrew|shell|terminfo|macos|all}\n"
        exit 1
        ;;
esac

echo -e
success "Done."
