#!/usr/bin/env bash
# Check the health of the dotfiles installation.

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
    local missing_apps=0
    title "Checking for installed apps"
    for util in "${utils[@]}"; do
        printf %s "Checking $util... "

        if test "$(command -v "$util")"; then
            success "Installed."
        else
            error "Not installed."
            missing_apps=$((missing_apps+1))
        fi
        printf %s "$newline"
    done

    if [ "$missing_apps" -gt 0 ]; then
        error "${newline}Missing required utilities. Install them to continue."
        exit 1
    fi
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

check_shell() {
    title "Checking shell"
    local zsh_path

    zsh_path="$(brew --prefix)/bin/zsh"

    printf %s "Checking Shell: $SHELL... "

    if [[ "$SHELL" = "$zsh_path" ]]; then 
        success "Accepted.$newline" 
    else
        error "Rejected.$newline$newline"
        color_print "$COLOR_BLUE" "Run \`./install.sh shell\` to setup the shell."
    fi

    printf %s "$newline"
}

check_xdg_config() {
    title "Checking XDG_CONFIG directory"
    local xdg_config="$HOME/.config"

    printf %s "Checking the existence of \"$xdg_config\"... "

    if [[ -d "$xdg_config" ]]; then
        success "Exists."
    else
        error "Missing.$newline$newline"
        color_print "$COLOR_BLUE" "XDG_CONFIG directory is missing. Run \`./install.sh link\` to set up."
    fi

    printf %s "$newline"
}

title "Dotfiles health check"

check_utils
check_shell
check_symlinks
check_xdg_config
