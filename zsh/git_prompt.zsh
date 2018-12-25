git_status() {
    dotfiles::is_git || return

    local git_branch="$vcs_info_msg_0_"
    git_branch="${git_branch#heads/}"
    git_branch="${git_branch/.../}"

    [[ -z "$git_branch" ]] && return

    local INDEX git_status=""

    GIT_SYMBOL="\ue725"
    GIT_STATUS_ADDED=$(dotfiles::print '002' '+')
    GIT_STATUS_MODIFIED=$(dotfiles::print '003' '!')
    GIT_STATUS_UNTRACKED=$(dotfiles::print '009' '?')
    GIT_STATUS_RENAMED=$(dotfiles::print '208' '»')
    GIT_STATUS_DELETED=$(dotfiles::print '017' '✘')
    GIT_STATUS_STASHED=$(dotfiles::print '003' '$')
    GIT_STATUS_UNMERGED=$(dotfiles::print '016' '=')
    GIT_STATUS_AHEAD=$(dotfiles::print '012' '⇡')
    GIT_STATUS_BEHIND=$(dotfiles::print '011' '⇣')
    GIT_STATUS_DIVERGED=$(dotfiles::print '012' '⇕')
    GIT_STATUS_CLEAN=$(dotfiles::print '002' '✔')

    INDEX=$(command git status --porcelain -b 2>/dev/null)

    # Check for untracked files
    if $(echo "$INDEX" | command grep -E '^\?\? ' &> /dev/null); then
        git_status="$GIT_STATUS_UNTRACKED$git_status"
    fi

    # Check for staged files
    if $(echo "$INDEX" | command grep '^A[ MDAU] ' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    elif $(echo "$INDEX" | command grep '^M[ MD] ' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    elif $(echo "$INDEX" | command grep '^UA' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    fi

    # Check for modified files
    if $(echo "$INDEX" | command grep '^[ MARC ]M ' &> /dev/null); then
        git_status="$GIT_STATUS_MODIFIED$git_status"
    fi

    # Check for renamed files
    if $(echo "$INDEX" | command grep '^R[ MD] ' &> /dev/null); then
        git_status="$GIT_STATUS_RENAMED$git_status"
    fi

    # Check for deleted files
    if $(echo "$INDEX" | command grep '^[MARCDU ]D ' &> /dev/null); then
        git_status="$GIT_STATUS_DELETED$git_status"
    elif $(echo "$INDEX" | command grep '^D[ UM] ' &> /dev/null); then
        git_status="$GIT_STATUS_DELETED$git_status"
    fi

    # Check for stashes
    if $(command git rev-parse --verify refs/stash >/dev/null 2>&1); then
        git_status="$GIT_STATUS_STASHED$git_status"
    fi

    # Check for unmerged files
    if $(echo "$INDEX" | command grep '^U[UDA] ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^AA ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^DD ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^[DA]U ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    fi

    # Check whether branch is ahead
    local is_ahead=false
    if $(echo "$INDEX" | command grep '^## [^ ]\+ .*ahead' &> /dev/null); then
        is_ahead=true
    fi

    # Check whether branch is behind
    local is_behind=false
    if $(echo "$INDEX" | command grep '^## [^ ]\+ .*behind' &> /dev/null); then
        is_behind=true
    fi

    # Check wheather branch has diverged
    if [[ "$is_ahead" == true && "$is_behind" == true ]]; then
        git_status="$GIT_STATUS_DIVERGED$git_status"
    else
        [[ "$is_ahead" == true ]] && git_status="$GIT_STATUS_AHEAD$git_status"
        [[ "$is_behind" == true ]] && git_status="$GIT_STATUS_BEHIND$git_status"
    fi

    [[ -n "$git_status" ]] || git_status="$GIT_STATUS_CLEAN"

    dotfiles::bold "$git_status"
    dotfiles::print '241' "$git_branch"
}
