# .zprofile is sourced on login shells and before .zshrc. As a general rule, it should not change the
# shell environment at all.

if [[ -f /opt/homebrew/bin/brew ]]; then
    # Homebrew exists at /opt/homebrew for arm64 macos
    eval $(/opt/homebrew/bin/brew shellenv)
elif [[ -f /usr/local/bin/brew ]]; then
    # or at /usr/local for intel macos
    eval $(/usr/local/bin/brew shellenv)
elif [[ -f /home/linuxbrew/.linuxbrew ]]; then
    # TODO: Can this just call brew shellenv too?
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew";
    export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar";
    export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew";
    export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:";
    export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH}";
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin${PATH+:$PATH}";
fi
