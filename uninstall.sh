#!/usr/bin/env bash
#
# uninstall.sh — reverse ./install.sh
#
# Removes the symlinks, machine-local files, repo-managed artifacts, and
# restores the login shell that ./install.sh created. Does NOT uninstall
# Homebrew or the dotfiles repo itself (see notes below).
#
# Usage:
#   ./uninstall.sh           # default: config + machine-local + shell
#   ./uninstall.sh --data    # also remove runtime data (nvim, atuin, opencode)
#
# Does NOT remove:
#   - Homebrew (/home/linuxbrew/.linuxbrew) — multi-user impact; run the
#     official uninstaller manually if needed:
#       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
#   - /etc/shells entries — left in place (other users may need them)
#   - the dotfiles repo ($DOTFILES) — printed as a hint at the end

set -u

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_MODE=0

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

# Remove a symlink only if it points into $DOTFILES; never touch real files
# or symlinks owned by other tools.
remove_dotfile_symlink() {
    local target="$1"
    if [ ! -L "$target" ]; then
        [ -e "$target" ] && warning "$target exists but is not a symlink — skipping."
        return 0
    fi
    local resolved
    resolved="$(readlink -f "$target" 2>/dev/null || true)"
    case "$resolved" in
        "$DOTFILES"/*)
            info "Removing symlink $target"
            rm "$target"
            ;;
        *)
            warning "$target is a symlink but not into $DOTFILES (-> $resolved) — skipping."
            ;;
    esac
}

remove_symlinks() {
    title "Removing symlinks"

    # *.symlink -> ~/.<basename>
    local linkables
    linkables=$(find -H "$DOTFILES" -maxdepth 3 -name '*.symlink' 2>/dev/null)
    local file
    for file in $linkables; do
        local target="$HOME/.$(basename "$file" '.symlink')"
        remove_dotfile_symlink "$target"
    done

    # config/<entry> -> ~/.config/<entry>
    local config
    if [ -d "$DOTFILES/config" ]; then
        config=$(find "$DOTFILES/config" -mindepth 1 -maxdepth 1 2>/dev/null)
        local entry
        for entry in $config; do
            remove_dotfile_symlink "$HOME/.config/$(basename "$entry")"
        done
    fi
}

remove_repo_artifacts() {
    title "Removing repo-managed artifacts"

    local oh_my_zsh="$DOTFILES/zsh/.oh-my-zsh"
    if [ -d "$oh_my_zsh" ]; then
        info "Removing $oh_my_zsh (oh-my-zsh + p10k + plugins)"
        rm -rf "$oh_my_zsh"
    fi

    local tpm_plugins="$DOTFILES/config/tmux/plugins"
    if [ -d "$tpm_plugins" ]; then
        info "Removing $tpm_plugins (TPM plugins)"
        rm -rf "$tpm_plugins"
    fi
}

remove_machine_local() {
    title "Removing machine-local files"

    # ~/.gitconfig-local (written by install.sh git)
    if [ -f "$HOME/.gitconfig-local" ]; then
        info "Removing ~/.gitconfig-local"
        rm -f "$HOME/.gitconfig-local"
    fi

    # ~/.git-credentials (git credential.helper store)
    if [ -f "$HOME/.git-credentials" ]; then
        info "Removing ~/.git-credentials"
        rm -f "$HOME/.git-credentials"
    fi

    # ~/.gitconfig — only remove if it contains solely the credential.helper
    # entry that setup_git wrote. Preserve any other config the user added.
    if [ -f "$HOME/.gitconfig" ]; then
        local non_cred
        non_cred=$(git config --file "$HOME/.gitconfig" --list --name-only 2>/dev/null \
                   | grep -v '^credential\.helper$' || true)
        if [ -z "$non_cred" ]; then
            info "Removing ~/.gitconfig (only contained credential.helper from setup_git)"
            rm -f "$HOME/.gitconfig"
        else
            warning "~/.gitconfig has other entries besides credential.helper — keeping file, removing only the helper entry."
            git config --file "$HOME/.gitconfig" --unset credential.helper 2>/dev/null || true
        fi
    fi

    # ~/.fzf.zsh (created by fzf install with --no-update-rc)
    if [ -f "$HOME/.fzf.zsh" ]; then
        info "Removing ~/.fzf.zsh"
        rm -f "$HOME/.fzf.zsh"
    fi

    # ~/.codegraph (CLI install dir, ~192M) + ~/.local/bin/codegraph symlink
    if [ -d "$HOME/.codegraph" ]; then
        info "Removing ~/.codegraph (codegraph CLI + versions)"
        rm -rf "$HOME/.codegraph"
    fi
    if [ -L "$HOME/.local/bin/codegraph" ]; then
        info "Removing ~/.local/bin/codegraph symlink"
        rm -f "$HOME/.local/bin/codegraph"
    fi
}

restore_shell() {
    title "Restoring login shell"

    if [ "$SHELL" = "/bin/bash" ]; then
        info "Login shell is already /bin/bash — nothing to do."
        return 0
    fi

    if ! command -v chsh >/dev/null 2>&1; then
        warning "chsh not found — cannot restore shell. Run 'chsh -s /bin/bash' manually."
        return 0
    fi

    info "Changing login shell back to /bin/bash"
    if chsh -s /bin/bash; then
        success "Login shell changed to /bin/bash (takes effect on next login)."
    else
        warning "chsh failed. Run 'chsh -s /bin/bash' manually."
    fi
    # /etc/shells is intentionally left untouched (other users may need the entry).
}

remove_runtime_data() {
    title "Removing runtime data (--data)"

    echo -e "${COLOR_RED}The following will be DELETED and cannot be recovered:${COLOR_NONE}"
    echo "  - ~/.local/share/nvim/  (lazy.nvim plugins + mason LSP, ~1.2G)"
    echo "  - ~/.cache/nvim/"
    echo "  - ~/.local/state/nvim/"
    echo "  - ~/.local/share/atuin/ (shell history database — IRREVERSIBLE)"
    echo "  - ~/.local/share/opencode/auth.json (opencode credentials — IRREVERSIBLE)"
    echo "  - ~/.config/opencode runtime files (node_modules, package.json, antigravity-*)"
    echo
    printf "Type 'yes' to confirm: "
    local reply
    read -r reply
    if [ "$reply" != "yes" ]; then
        warning "Aborted --data removal."
        return 0
    fi

    # nvim data (reinstallable via :Lazy sync)
    local nvim_dirs=("$HOME/.local/share/nvim" "$HOME/.cache/nvim" "$HOME/.local/state/nvim")
    local d
    for d in "${nvim_dirs[@]}"; do
        if [ -d "$d" ]; then
            info "Removing $d"
            rm -rf "$d"
        fi
    done

    # atuin history (irreversible)
    if [ -d "$HOME/.local/share/atuin" ]; then
        info "Removing ~/.local/share/atuin (shell history)"
        rm -rf "$HOME/.local/share/atuin"
    fi

    # opencode auth (irreversible)
    if [ -f "$HOME/.local/share/opencode/auth.json" ]; then
        info "Removing ~/.local/share/opencode/auth.json (credentials)"
        rm -f "$HOME/.local/share/opencode/auth.json"
    fi

    # opencode runtime files inside the repo config dir (gitignored)
    local oc_dir="$DOTFILES/config/opencode"
    local oc_junk=(node_modules package.json package-lock.json bun.lock
                   antigravity-accounts.json antigravity-signature-cache.json
                   antigravity-logs)
    local j
    for j in "${oc_junk[@]}"; do
        if [ -e "$oc_dir/$j" ]; then
            info "Removing $oc_dir/$j"
            rm -rf "$oc_dir/$j"
        fi
    done
}

print_homebrew_hint() {
    echo
    warning "Homebrew was NOT uninstalled (multi-user safety). To remove it manually:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
}

print_repo_hint() {
    echo
    info "The dotfiles repo itself was not removed. To delete it:"
    echo "  rm -rf \"$DOTFILES\""
}

# ---- parse args ----
case "${1:-}" in
    --data) DATA_MODE=1 ;;
    ""|--help|-h)
        if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
            echo "Usage: ./uninstall.sh [--data]"
            echo "  (no arg)  remove symlinks, repo artifacts, machine-local files, restore shell"
            echo "  --data    also remove nvim/atuin/opencode runtime data (prompts for confirmation)"
            exit 0
        fi
        ;;
    *) error "Unknown option: $1 (try --help)" ;;
esac

# ---- run ----
remove_symlinks
remove_repo_artifacts
remove_machine_local
restore_shell

if [ "$DATA_MODE" -eq 1 ]; then
    remove_runtime_data
fi

print_homebrew_hint
print_repo_hint

echo -e
success "Uninstall complete."
