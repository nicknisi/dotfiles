#!/usr/bin/env bash
# Now-playing chip via bin/current-song ("Title - Artist", empty when no
# player is running). Hidden when silent. Note: a paused track still
# reports — current-song queries the track, not player state.

source "$CONFIG_DIR/colors.sh"

SONG=$("$HOME/Developer/dotfiles/bin/current-song" 2>/dev/null)

if [ -n "$SONG" ]; then
  sketchybar --animate tanh 30 --set "$NAME" drawing=on label="$SONG"
else
  sketchybar --set "$NAME" drawing=off
fi
