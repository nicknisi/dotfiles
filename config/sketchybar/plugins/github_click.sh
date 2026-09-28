#!/usr/bin/env bash
# GitHub chip clicks: left = toggle the PR dropdown, right = the old
# behavior (jump to the web workspace, open the pulls page).

case "$BUTTON" in
right)
  "$CONFIG_DIR/plugins/wm.sh" focus-label W || exit 1
  open https://github.com/pulls/review-requested
  ;;
*)
  sketchybar --set github popup.drawing=toggle
  ;;
esac
