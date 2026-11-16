# .zprofile is sourced on login shells and before .zshrc. As a general rule, it should not change the
# shell environment at all.

if [[ -f /opt/homebrew/bin/brew ]]; then
    # Homebrew exists at /opt/homebrew for arm64 macos
    eval $(/opt/homebrew/bin/brew shellenv)
elif [[ -f /usr/local/bin/brew ]]; then
    # or at /usr/local for intel macos
    eval $(/usr/local/bin/brew shellenv)
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
    # or from linuxbrew
    test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
    test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if [[ -x "$(command -v rbenv)" ]]; then
  eval "$(rbenv init - --no-rehash zsh)";
fi

# Linux: tty1 logs in at boot (the getty@tty1 drop-in in config/mise/files) and
# this hands that shell to uwsm, which runs Hyprland. It stays last because uwsm
# captures this shell's environment, and the $TTY test keeps uwsm's startup out
# of tmux panes and ssh logins. pam_systemd tags a tty login
# XDG_SESSION_TYPE=tty, which Chromium and Electron apps read to pick X11.
if [[ $OSTYPE == linux* && $TTY == /dev/tty1 ]] && (( $+commands[uwsm] )) &&
    uwsm check may-start -q; then
    export XDG_SESSION_TYPE=wayland
    exec uwsm start -e -D Hyprland hyprland.desktop
fi
