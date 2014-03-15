# this is specific to the location of the current version of git, installed by homebrew
completion=/usr/local/Cellar/git/1.8.0.1/etc/bash_completion.d/git-completion.bash

if test -f $completion; then
    source $completion
fi
