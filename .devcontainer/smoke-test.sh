#!/usr/bin/env bash

set -Eeuo pipefail

export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"

[[ "$(uname -s)" == "Linux" ]]
[[ "$(getent passwd "$(id -un)" | cut -d: -f7)" == "/usr/bin/zsh" ]]
[[ -S "${SSH_AUTH_SOCK:-}" ]]
ssh-add -l >/dev/null

mise bootstrap packages status --missing >/dev/null
mise bootstrap repos status --missing >/dev/null
mise bootstrap dotfiles status --missing >/dev/null
mise bootstrap user status --missing >/dev/null
[[ -z "$(mise ls --missing)" ]]

TERM=xterm-256color script -qec \
  "zsh -lic '[[ \$DOTFILES == \$HOME/Developer/dotfiles && \$PNPM_HOME == \$HOME/.local/share/pnpm ]]'" \
  /dev/null >/dev/null
[[ "$(git config --global --get core.pager)" == "delta" ]]

nvim_log="$(mktemp)"
if ! nvim --headless '+lua if vim.v.errmsg ~= "" then error(vim.v.errmsg) end' '+qa' >"$nvim_log" 2>&1; then
  cat "$nvim_log" >&2
  rm -f "$nvim_log"
  exit 1
fi
rm -f "$nvim_log"

socket="dotfiles-smoke-$$"
trap 'tmux -L "$socket" kill-server 2>/dev/null || true' EXIT
TMUX_MINIMAL=1 tmux -L "$socket" -f "$HOME/.config/tmux/tmux.conf" new-session -d -s smoke
[[ "$(tmux -L "$socket" display-message -p -t smoke '#{session_name}')" == "smoke" ]]

echo "devcontainer smoke test passed"
