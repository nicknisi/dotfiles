# yazi shell integration — terminal file manager with image preview
# https://github.com/sxyazi/yazi
# This file is auto-sourced by zshrc.symlink (matches $DOTFILES/**/*.zsh glob).
# yazi is installed by `./install.sh homebrew` (see Brewfile); config is
# symlinked to ~/.config/yazi/ by `./install.sh link`.

if command -v yazi >/dev/null 2>&1; then
  # `y` — launch yazi (short alias, matches `n` for nvim)
  alias y='yazi'

  # `yc` — launch yazi and cd to the directory it was in on quit.
  # Uses yazi's --cwd-file flag (no temp-file tricks needed, unlike nnn).
  # Replaces the former `cdn` function for nnn (zsh/quitcd.zsh, removed).
  yc() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi --cwd-file="$tmp" "$@"
    local cwd="$(command cat -- "$tmp")"
    if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi
