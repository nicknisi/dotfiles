#!/usr/bin/env bash
# Omarchy theme-set hook — make running tmux servers re-read the theme.
# The tmux.conf theme loader reads
# ~/.local/state/omarchy/current/theme/colors.toml, so re-sourcing the config
# after `omarchy theme set` restyles everything live.
#
# Install once:
#   omarchy hook install theme-set <dotfiles>/config/tmux/theme/omarchy-hook.sh

if tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 || true
fi
