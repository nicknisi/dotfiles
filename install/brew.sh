#!/bin/sh

if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "\n\nInstalling homebrew packages..."
echo "=============================="

formulas=(
    ack
    diff-so-fancy
    dnsmasq
    fzf
    git
    'grep --with-default-names'
    highlight
    hub
    markdown
    neovim/neovim/neovim
    node
    nginx
    reattach-to-user-namespace
    the_silver_searcher
    tmux
    tree
    wget
    vim
    z
    zsh
    ripgrep
    git-standup
    entr
    zsh-autosuggestions
    zsh-syntax-highlighting
)

for formula in "${formulas[@]}"; do
    if brew list "$formula" > /dev/null 2>&1; then
        echo "$formula already installed... skipping."
    else
        brew install $formula
    fi
done

# After the install, setup fzf
echo "\n\nRunning fzf install script..."
echo "=============================="
/usr/local/opt/fzf/install --all --no-bash --no-fish
