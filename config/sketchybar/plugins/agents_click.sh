#!/usr/bin/env bash
# Agents pill clicks: left = fleet dashboard popup (mirrors prefix-y),
# right = jump to next waiting agent (mirrors prefix-n).

aerospace workspace D

case "$BUTTON" in
right)
  fleet next || tmux display-message "fleet next: no waiting agents"
  ;;
*)
  tmux display-popup -E -w 90% -h 80% fleet
  ;;
esac
