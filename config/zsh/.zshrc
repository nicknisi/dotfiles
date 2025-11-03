export ZSH=$DOTFILES/zsh

source "$ZDOTDIR/.zsh_functions"

########################################################
# Configuration
########################################################

# initialize autocomplete
autoload -U compinit add-zsh-hook
compinit

# setup PATH
for dir in $HOME/.cargo/bin $HOME/.local/bin /usr/local/opt/grep/libexec/gnubin /usr/local/sbin $DOTFILES/bin $HOME/bin; do
  prepend_path $dir
done

# define the code directory
# This is where my code exists and where I want the `c` autocomplete to work from exclusively
if [[ -d ~/code ]]; then
  export CODE_DIR=~/code
elif [[ -d ~/Developer ]]; then
  export CODE_DIR=~/Developer
fi

# display how long all tasks over 10 seconds take
export REPORTTIME=10
export KEYTIMEOUT=1              # 10ms delay for key sequences

setopt NO_BG_NICE
setopt NO_HUP                    # don't kill background jobs when the shell exits
setopt NO_LIST_BEEP
setopt LOCAL_OPTIONS
setopt LOCAL_TRAPS
setopt PROMPT_SUBST

# history
setopt EXTENDED_HISTORY          # write the history file in the ":start:elapsed;command" format.
setopt HIST_REDUCE_BLANKS        # remove superfluous blanks before recording entry.
setopt SHARE_HISTORY             # share history between all sessions.
setopt HIST_IGNORE_ALL_DUPS      # delete old recorded entry if new entry is a duplicate.

setopt COMPLETE_ALIASES

# make terminal command navigation sane again
# navigation key bindings
bindkey "^[[1;5C" forward-word      # [Ctrl-right] - forward one word
bindkey "^[[1;5D" backward-word     # [Ctrl-left] - backward one word
bindkey '^[^[[C' forward-word
bindkey '^[^[[D' backward-word
bindkey '^[[1;3D' beginning-of-line  # [Alt-left] - beginning of line
bindkey '^[[1;3C' end-of-line        # [Alt-right] - end of line
bindkey '^[[5D' beginning-of-line
bindkey '^[[5C' end-of-line
bindkey '^?' backward-delete-char

# delete key handling
if [[ -n "${terminfo[kdch1]}" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char
else
  for key in "^[[3~" "^[3;5~" "\e[3~"; do
    bindkey "$key" delete-char
  done
fi

# vi mode bindings
bindkey "^A" vi-beginning-of-line
bindkey -M viins "^F" vi-forward-word
bindkey -M viins "^E" vi-add-eol
bindkey "^J" history-beginning-search-forward
bindkey "^K" history-beginning-search-backward

# matches case insensitive for lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# default to file completion
zstyle ':completion:*' completer _expand _complete _files _correct _approximate

zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*' group-name ''


########################################################
# Plugin setup
########################################################

export ZPLUGDIR="$CACHEDIR/zsh/plugins"
[[ -d "$ZPLUGDIR" ]] || mkdir -p "$ZPLUGDIR"
# array containing plugin information (managed by zfetch)
typeset -A plugins

zfetch mafredri/zsh-async async.plugin.zsh
zfetch zsh-users/zsh-syntax-highlighting
zfetch zsh-users/zsh-autosuggestions
zfetch grigorii-zander/zsh-npm-scripts-autocomplete
zfetch Aloxaf/fzf-tab

command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd)"

[[ -e ~/.terminfo ]] && export TERMINFO_DIRS=~/.terminfo:/usr/share/terminfo

########################################################
# Setup
########################################################

if command -v fzf &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_DEFAULT_OPTS="--color bg:-1,bg+:-1,fg:-1,fg+:#feffff,hl:#993f84,hl+:#d256b5,info:#676767,prompt:#676767,pointer:#676767"
  source <(fzf --zsh)
fi

# colored man pages
export MANROFFOPT='-c'
typeset -A man_colors=(
  mb "$(tput bold; tput setaf 2)"
  md "$(tput bold; tput setaf 6)"
  me "$(tput sgr0)"
  so "$(tput bold; tput setaf 3; tput setab 4)"
  se "$(tput rmso; tput sgr0)"
  us "$(tput smul; tput bold; tput setaf 7)"
  ue "$(tput rmul; tput sgr0)"
  mr "$(tput rev)"
  mh "$(tput dim)"
)
for key val in ${(kv)man_colors}; do
  export LESS_TERMCAP_$key=$val
done

# directory jumping: prefer zoxide over z.sh
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --hook pwd)"
elif [[ -f "$(brew --prefix 2>/dev/null)/etc/profile.d/z.sh" ]]; then
  source "$(brew --prefix)/etc/profile.d/z.sh"
fi

# detect ls flavor and set color flag
colorflag=$(ls --color &>/dev/null && echo "--color" || echo "-G")

# source local and config files
for file in ~/.zshrc.local "$ZDOTDIR/.zsh_prompt" "$ZDOTDIR/.zsh_aliases"; do
  [[ -f "$file" ]] && source "$file"
done


if command -v pnpm &>/dev/null; then
  export PNPM_HOME="$HOME/Library/pnpm"
  [[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"
fi

if command -v pyenv &>/dev/null; then
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi
