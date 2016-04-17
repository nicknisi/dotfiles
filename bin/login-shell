#!/usr/bin/env bash

shell=$(basename "$SHELL")

# check if reattach-to-user-namespace is available
if [ -n "$(command -v reattach-to-user-namespace)" ]; then
    reattach-to-user-namespace -l "$shell"
else
    exec "$shell -l"
fi
