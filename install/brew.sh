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
    direnv
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
    python
    python3
    rbenv
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

# after hte install, install neovim python libraries
echo "\n\nRunning Neovim Python install"
echo "=============================="
pip2 install --user neovim
pip3 install --user neovim

# Change the default shell to zsh
zsh_path="$(which zsh)"
if ! grep "$zsh_path" /etc/shells; then
    echo "adding $zsh_path to /etc/shells"
    echo "$zsh_path" | sudo tee -a /etc/shells
fi

if [[ "$SHELL" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
    echo "default shell changed to $zsh_path"
fi
