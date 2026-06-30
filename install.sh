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

get_linkables() {
    find -H "$DOTFILES" -maxdepth 3 -name '*.symlink'
}

backup() {
    BACKUP_DIR=$HOME/dotfiles-backup

    echo "Creating backup directory at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    for file in $(get_linkables); do
        filename=".$(basename "$file" '.symlink')"
        target="$HOME/$filename"
        if [ -f "$target" ]; then
            echo "backing up $filename"
            cp "$target" "$BACKUP_DIR"
        else
            warning "$filename does not exist at this location or is a symlink"
        fi
    done

    for filename in "$HOME/.config/nvim" "$HOME/.vim" "$HOME/.vimrc"; do
        if [ ! -L "$filename" ]; then
            echo "backing up $filename"
            cp -rf "$filename" "$BACKUP_DIR"
        else
            warning "$filename does not exist at this location or is a symlink"
        fi
    done
}


setup_symlinks() {
    title "Creating symlinks"

    for file in $(get_linkables) ; do
        target="$HOME/.$(basename "$file" '.symlink')"
        if [ -e "$target" ]; then
            info "~${target#$HOME} already exists... Skipping."
        else
            info "Creating symlink for $file"
            ln -s "$file" "$target"
        fi
    done

    echo -e
    info "installing to ~/.config"
    if [ ! -d "$HOME/.config" ]; then
        info "Creating ~/.config"
        mkdir -p "$HOME/.config"
    fi

    config_files=$(find "$DOTFILES/config" -mindepth 1 -maxdepth 1 2>/dev/null)
    for config in $config_files; do
        target="$HOME/.config/$(basename "$config")"
        if [ -e "$target" ]; then
            info "~${target#$HOME} already exists... Skipping."
        else
            info "Creating symlink for $config"
            ln -s "$config" "$target"
        fi
    done
}

setup_git() {
    title "Setting up Git"

    defaultName=$(git config user.name)
    defaultEmail=$(git config user.email)
    defaultGithub=$(git config github.user)

    read -rp "Name [$defaultName] " name
    read -rp "Email [$defaultEmail] " email
    read -rp "Github username [$defaultGithub] " github

    git config -f ~/.gitconfig-local user.name "${name:-$defaultName}"
    git config -f ~/.gitconfig-local user.email "${email:-$defaultEmail}"
    git config -f ~/.gitconfig-local github.user "${github:-$defaultGithub}"

    read -rn 1 -p "Save user and password to an unencrypted file to avoid writing? [y/N] " save
    if [[ $save =~ ^([Yy])$ ]]; then
        git config --global credential.helper "store"
    else
        git config --global credential.helper "cache --timeout 3600"
    fi
}

setup_homebrew() {
    title "Setting up Homebrew"

    # Put any existing brew on PATH before deciding what to do. shellenv only
    # reads the prefix, so this is safe for non-owner users too.
    if [ "$(uname)" == "Linux" ]; then
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    if test ! "$(command -v brew)"; then
        # brew absent (fresh machine). Download-then-run instead of piping so
        # bash keeps a TTY stdin: the Homebrew installer then stays interactive
        # and can prompt for the sudo password it needs to create the supported
        # /home/linuxbrew/.linuxbrew prefix. Piping (curl | bash) forces
        # NONINTERACTIVE=1 -> sudo -n -> "a password is required" abort even
        # for users who do have sudo.
        info "Homebrew not installed. Installing."
        local brew_installer="/tmp/brew-install-$$.sh"
        if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh -o "$brew_installer"; then
            rm -f "$brew_installer"
            error "Failed to download Homebrew installer."
        fi
        bash --login "$brew_installer"; local rc=$?
        rm -f "$brew_installer"
        [ $rc -ne 0 ] && error "Homebrew installation failed (exit $rc)."
        if [ "$(uname)" == "Linux" ]; then
            test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
            test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi

    local prefix
    prefix="$(brew --prefix 2>/dev/null)"
    if [ ! -w "$prefix" ]; then
        # Homebrew exists but is owned by another user (e.g. test5 reusing an
        # install done by wl_ubuntu). Skip brew bundle / fzf install: those
        # write to the prefix (Cellar, locks, opt) and would fail with
        # "Permission denied @ rb_sysopen .../locks/...". Pre-installed
        # binaries stay usable via PATH. Homebrew is designed for single-user
        # ownership; this read-only reuse is the supported multi-user pattern.
        warning "Homebrew prefix ($prefix) is not writable by $USER; skipping 'brew bundle'."
        warning "Installed binaries remain usable on PATH. Ask the prefix owner to run './install.sh homebrew' to install or update packages."
        return 0
    fi

    # install brew dependencies from Brewfile
    brew bundle

    # install fzf
    echo -e
    info "Installing fzf"
    "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

setup_shell() {
    title "Configuring shell"

    [[ -n "$(command -v brew)" ]] && zsh_path="$(brew --prefix)/bin/zsh" || zsh_path="$(which zsh)"
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        info "adding $zsh_path to /etc/shells"
        if sudo -n true 2>/dev/null; then
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        else
            warning "Cannot write to /etc/shells without sudo. Run this manually as an admin:"
            warning "  echo '$zsh_path' | sudo tee -a /etc/shells"
            warning "Then re-run './install.sh shell', or run 'chsh -s $zsh_path' directly if the path is already listed."
        fi
    fi

    if [[ "$SHELL" != "$zsh_path" ]]; then
        if grep -q "$zsh_path" /etc/shells 2>/dev/null; then
            chsh -s "$zsh_path"
            info "default shell changed to $zsh_path"
        else
            warning "Skipped chsh: $zsh_path is not in /etc/shells. Add it first (see above)."
        fi
    fi
}

# CodeGraph — pre-indexed code knowledge graph for AI agents (opencode, etc.).
# Not on Homebrew; the official installer bundles its own Node runtime and
# places `codegraph` on a user-level bin already on PATH (~/.local/bin, see
# zshenv.symlink). Idempotent: skips if `codegraph` is already on PATH.
# Per-project indexing (`codegraph init`) is NOT done here — only the global
# CLI. The opencode MCP wiring lives in config/opencode/opencode.json.
setup_codegraph() {
    title "Setting up CodeGraph"

    if command -v codegraph >/dev/null 2>&1; then
        info "codegraph already installed ($(codegraph --version 2>/dev/null || echo present)), skipping."
    else
        info "Installing CodeGraph via official installer (bundles its own Node runtime)."
        curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
    fi
}

setup_ohmyzsh() {
    title "Configuring ohmyzsh"

    # Set defaults so the guards below work under bash (install.sh's shebang),
    # where $ZSH/$ZSH_CUSTOM are normally only set by zshrc in an interactive zsh.
    ZSH="${ZSH:-$DOTFILES/zsh/.oh-my-zsh}"
    ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

    if ! [[ -d "$ZSH" ]]; then
        info "install ohmyzsh"
        RUNZSH="no" KEEP_ZSHRC="yes" ZSH="$DOTFILES/zsh/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        info  "ohmyzsh have already installed"
    fi

    if ! [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
        info "install the theme of ohmyzsh"

        # install theme
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

        # install custom plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    else
        info "p10k have already installed"
    fi
}

case "$1" in
    backup)
        backup
        ;;
    link)
        setup_symlinks
        ;;
    git)
        setup_git
        ;;
    homebrew)
        setup_homebrew
        ;;
    ohmyzsh)
        setup_ohmyzsh
        ;;
    shell)
        setup_shell
        ;;
    codegraph)
        setup_codegraph
        ;;
    all)
        setup_symlinks
        setup_homebrew
        setup_git
        setup_ohmyzsh
        setup_shell
        setup_codegraph
        ;;
    *)
        echo -e $"\nUsage: $(basename "$0") {backup|link|git|homebrew|ohmyzsh|shell|codegraph|all}\n"
        exit 1
        ;;
esac

echo -e
success "Done."
