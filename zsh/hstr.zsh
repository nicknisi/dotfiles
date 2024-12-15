# HSTR configuration - add this to ~/.zshrc
alias hh=hstr                    # hh to be alias for hstr
setopt histignorespace           # skip cmds w/ leading space from history
bindkey -s "\C-r" "\C-a hstr -- \C-j"     # bind hstr to Ctrl-r (for Vi mode check doc)

# https://github.com/dvorka/hstr/blob/master/CONFIGURATION.md#hstr-config-options
export HSTR_CONFIG=raw-history-view,prompt-bottom
export HSTR_TIOCSTI=y
