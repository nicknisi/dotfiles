# Atuin shell integration — magical shell history (https://atuin.sh)
# This file is auto-sourced by zshrc.symlink AFTER oh-my-zsh, so atuin's
# Ctrl-R supersedes the fzf plugin's Ctrl-R. fzf's Ctrl-T (files) and
# Alt-C (directories) are unaffected and still work.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi
