node_prompt() {
    [[ -f package.json || -d node_modules ]] || return

    local version=''
    local node_icon='\ue718'

    if dotfiles::exists node; then
        version=$(node -v 2>/dev/null)
    fi

    [[ -n version ]] || return

    dotfiles::print '041' "$node_icon $version"
}
