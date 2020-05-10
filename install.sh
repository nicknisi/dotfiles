#!/usr/bin/env bash

command_exists() {
    type "$1" > /dev/null 2>&1
}

echo "Installing dotfiles."

source install/link.sh

source install/git.sh

if ! command_exists brew; then
    echo -e "\\n\\nInstalling homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

    # install brew dependencies from Brewfile
    BASEDIR=$(dirname "$0")
    cd "$BASEDIR" || { echo "Directory $BASEDIR not found" ; exit 1; }
    echo "Installing brew dependencies from Brewfile"
    brew bundle
    cd - || { echo "Couldn't go back to the previous directory" ; exit 1; }

    echo -e "\\n\\nInstalling Neovim support for Python libraries"
    echo "=============================="
    pip3 install pynvim
fi

# only perform macOS-specific install
if [ "$(uname)" == "Darwin" ]; then
    echo -e "\\n\\nRunning on macOS"

    # After the install, setup fzf
    echo -e "\\n\\nRunning fzf install script..."
    echo "=============================="
    /usr/local/opt/fzf/install --all --no-bash --no-fish

    source install/osx.sh
fi

if ! command_exists zsh; then
    echo "zsh not found. Please install and then re-run installation scripts"
    exit 1
fi

zsh_path="$( command -v zsh )"
if ! grep "$zsh_path" /etc/shells; then
    echo -e "\\n\\nChanging default shell to zsh"
    echo "adding $zsh_path to /etc/shells"
    echo "$zsh_path" | sudo tee -a /etc/shells
fi

if ! [[ $SHELL =~ .*zsh.* ]]; then
    chsh -s "$zsh_path"
    echo "default shell changed to $zsh_path"

    zsh # Reload terminal
fi

