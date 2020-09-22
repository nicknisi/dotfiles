autoload -Uz vcs_info
autoload -Uz add-zsh-hook
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats ' %b'

# add-zsh-hook precmd vcs_info

source "$DOTFILES/zsh/git_prompt.zsh"
source "$DOTFILES/zsh/jobs_prompt.zsh"
source "$DOTFILES/zsh/node_prompt.zsh"

async_init
async_start_worker vcs_info
async_register_callback vcs_info git_status_done

PROMPT_SYMBOL='❯'

add-zsh-hook precmd () {
    print -P "\n%F{005}%~ $(node_prompt)"
    async_job vcs_info git_status
}

node_prompt() {
    [[ -f package.json || -d node_modules ]] || return

    local version=''
    local node_icon='\ue718'

    if dotfiles::exists node; then
        version=$(node -v 2>/dev/null)
    fi

    [[ -n version ]] || return

    dotfiles::print '029' "$node_icon $version"
}

export PROMPT='%(?.%F{006}.%F{009})$PROMPT_SYMBOL%f '
export RPROMPT=''
