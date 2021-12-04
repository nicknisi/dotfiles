#!/usr/bin/env bash

# abort if we're already inside a TMUX session
[ "$TMUX" == "" ] || exit 0

# present menu for user to choose which workspace to open
PS3="Please choose your session: "
# shellcheck disable=SC2207
IFS=$'\n' && options=("New Session" $(tmux list-sessions -F "#S" 2>/dev/null))
echo "Available sessions"
echo "------------------"
echo " "
select opt in "${options[@]}"
do
    case $opt in
        "New Session")
            read -rp "Enter new session name: " SESSION_NAME
            tmux new -s "$SESSION_NAME"
            break
            ;;
        *)
            tmux attach-session -t "$opt"
            break
            ;;
    esac
done
