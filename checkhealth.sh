#!/usr/bin/env bash
# Check the health of the dotfiles installation.

# Things to check:
# - [X] check key utilies are installed
# - [X] check symlinks
# - [ ] check XDG_CONFIG
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
            success "Installed."
        else
            warning "Not installed."
        fi
        printf %s "$newline"
    done
}

check_symlinks() {
    title "Checking Symlinks"
    local symlink_issues=0
    local dotfile
    local actual
    local target

    for link in $(get_linkables) ; do
        dotfile=".$(basename "$link" ".symlink")"
        target="$HOME/$dotfile"
        printf %s "Checking for Symlink \"~/$dotfile\"... "
        if [[ -h "$target" ]]; then
            actual="$(readlink "$target")"
            if [ "$link" != "$actual" ]; then
                warning "Incorrect.$newline"
                color_print "$COLOR_YELLOW" "Expected symlink to point to "
                color_print "$COLOR_GRAY" "$link$newline"
                color_print "$COLOR_RED" "But it points to "
                color_print "$COLOR_GRAY" "$actual$newline"
                color_print "$COLOR_BLUE" "${newline}Delete the symlink and run \`./install.sh link\`$newline"
                symlink_issues=$((symlink_issues+1))
            else
                success "Exists."
            fi
        else
            error "Missing."
            symlink_issues=$((symlink_issues+1))
        fi
        printf %s "$newline"
    done

    if [ "$symlink_issues" -gt 0 ]; then
        error "${newline}There were $symlink_issues issue(s).$newline"
        color_print "$COLOR_BLUE" "${newline}Run \`./install.sh link\` to correct.$newline"
    fi
}

title "Dotfiles health check"

check_utils
check_symlinks
