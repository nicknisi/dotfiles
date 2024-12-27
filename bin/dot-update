#!/usr/bin/env bash
# Description: Update all the things

set -Eeuo pipefail

# source helpers
source "$DOTFILES/bin/lib/common.sh"
command_name=$(basename "${BASH_SOURCE[0]}")

usage() {
  cat <<EOF
  $(fmt_key "Usage:") $(fmt_key "$command_name") $(fmt_value "[options] <command>")

  Update all the things. This script can be used to update Neovim plugins,
  update Homebrew packages, and more.

Options:
    -h, --help           Show this help message
    -v, --verbose        Show verbose output
    nvim, vim            Update Neovim plugins
    homebrew, brew       Update Homebrew packages
    dotfiles             Update dotfiles
    zsh                  Update Zsh plugins
    all                  Update everything
EOF
}

update_homebrew() {
  fmt_title_underline "Updating Homebrew packages"
  local log_file=$(mktemp)
  trap 'rm -f "$log_file"' EXIT

  run_with_spinner "brew update > '$log_file' 2>&1 && brew upgrade > '$log_file' 2>&1" 11 "Updating Homebrew"

  if grep -q "Error\|fatal\|Failed" "$log_file"; then
    log_error "Error occurred during update:"
    [[ "$verbose" == true ]] && cat "$log_file"
    exit 1
  fi

  grep -A1 "=>" "$log_file" | grep -v "^--$" || log_info "No updates found"
  echo -e
}

update_nvim_plugins() {
  fmt_title_underline "Updating Neovim plugins"

  local log_file=$(mktemp)
  trap 'rm -f "$log_file"' EXIT

  # Use run_with_spinner helper with style 11 (complex braille pattern)
  run_with_spinner "nvim --headless '+Lazy! sync' +qa > '$log_file' 2>&1" 11 "Updating Neovim plugins"

  # Check for errors
  if grep -q "Error\|ERROR\|Could not\|not installed" "$log_file"; then
    echo "Error occurred during update:"
    rm -f "$temp_lua" "$log_file"
    exit 1
  fi

  grep -i "updated\|installed\|removed" "$log_file" || log_info "No updates found"
  echo -e
}

update_dotfiles() {
  fmt_title_underline "Updating dotfiles"

  current_branch="$(git -C "$DOTFILES" symbolic-ref --short HEAD)"
  if [ "$current_branch" != "main" ]; then
    log_warning "Not on main branch (current: $current_branch)"
    return 1
  fi

  local log_file=$(mktemp)

  trap 'rm -f "$log_file"' EXIT

  # Fetch updates with spinner
  run_with_spinner "git -C '$DOTFILES' fetch --quiet origin main > '$log_file' 2>&1" 11 "Checking for dotfiles updates"

  # Compare local with remote
  local_rev=$(git -C "$DOTFILES" rev-parse HEAD)
  remote_rev=$(git -C "$DOTFILES" rev-parse "@{u}" 2>/dev/null)

  if [ "$local_rev" = "$remote_rev" ]; then
    log_info "Dotfiles are up to date"
    return 0
  fi

  echo "Updates available:"
  git -C "$DOTFILES" --no-pager log --oneline --graph --decorate --color=always HEAD.."@{u}"
  # Try to update if everything is clean
  run_with_spinner "git -C '$DOTFILES' pull --ff-only origin main > '$log_file' 2>&1" 11 "Updating dotfiles"

  if [ $? -eq 0 ]; then
    log_info "Dotfiles updated successfully"
  else
    log_error "Failed to update dotfiles"
    cat "$log_file"
    return 1
  fi
}

update_zsh_plugins() {
  fmt_title_underline "Updating ZSH plugins..."
  echo -e

  local cwd="$(pwd)"
  while IFS=: read -r name path; do
    # update logic here
    cd "$path" || exit

    local before=$(git rev-parse HEAD)

    run_with_spinner 'git pull --quiet --recurse-submodules' 11 "Updating $name..."

    # Check if anything changed
    local after=$(git rev-parse HEAD)
    if [[ $before != $after ]]; then
      local commit_count=$(git rev-list --count "$before".."$after")
      local commit_msg=$(git log -1 --pretty=format:"%s")
      log_success "$name updated ($commit_count new commit(s))"
      fmt_value "  → $commit_msg"
    else
      log_info "$name already up to date"
    fi

    cd "$cwd" || exit
  done < <(zsh -ic 'for k in ${(k)plugins}; do echo "$k:$plugins[$k]"; done')

  echo -e
  log_success "ZSH Plugin updates completed."
}

main() {
  local subcmd=""
  local verbose=false

  if [ $# -lt 1 ]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --verbose)
      verbose=true
      shift
      ;;
    *)
      subcmd="$1"
      shift
      ;;
    esac
  done

  case "$subcmd" in
  nvim | vim)
    update_nvim_plugins
    ;;
  homebrew | brew)
    update_homebrew
    ;;
  dotfiles)
    update_dotfiles
    ;;
  zsh)
    update_zsh_plugins
    ;;
  all)
    update_nvim_plugins
    update_homebrew
    update_zsh_plugins
    update_dotfiles
    ;;
  *)
    log_error "Unknown $command_name command: $subcmd"
    echo -e
    usage
    exit 1
    ;;
  esac
}

main "$@"
