#!/usr/bin/env bash
# Check the health of the dotfiles installation.

# Things to check:
# - [ ] check symlinks
# - [ ] check XDG_CONFIG
# - [ ] check key utilies are installed
# - [ ] check shell
# - [ ] check the path

COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"
newline=$'\n'

color_print() {
    printf "%b%s%b" "$1" "$2" "$COLOR_NONE"
}

title() {
    echo -e "\n${COLOR_PURPLE}$1${COLOR_NONE}"
    echo -e "${COLOR_GRAY}==============================${COLOR_NONE}\n"
}

error() {
    color_print "$COLOR_RED" "$*"
}

warning() {
    color_print "$COLOR_YELLOW" "$*"
}

success() {
    color_print "$COLOR_GREEN" "$*"
}

get_linkables() {
    find -H "$DOTFILES" -maxdepth 3 -name '*.symlink'
}

check_utils() {
    local utils=(git brew tmux nvim kitty)
    title "Checking for installed apps"
    for util in "${utils[@]}"; do
        printf %s "Checking $util... "

        if test "$(command -v "$util")"; then
            success "Exists."
        else
            warning "MISSING. "
        fi
        printf %s "$newline"
    done
}

check_symlinks() {
    title "Checking Symlinks"

    for link in $(get_linkables) ; do
        target="$HOME/.$(basename "$link" '.symlink')"
        printf %s "Checking Symlink for \".$(basename "$link" ".symlink")\"... "
        if [[ -h "$target" ]]; then
            if [ "$link" != "$(readlink "$target")" ]; then
                warn "$target is not properly symlinked"
            else
                success "Exists."
            fi
        else
            warn "$target symlink is missing."
        fi
        printf %s "$newline"
    done
}

# title "Dotfiles health check"

# check_utils
check_symlinks
