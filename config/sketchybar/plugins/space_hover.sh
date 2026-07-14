#!/usr/bin/env bash
# Hover = the pill's hairline warms to the accent ring; no fills change,
# light does the work. Data rendering lives in workspaces.sh.

source "$CONFIG_DIR/colors.sh"

FOCUSED=$(cat "$HOME/.cache/sketchybar/focused-workspace" 2>/dev/null)

case "$SENDER" in
mouse.entered)
  [ "$NAME" = "space.$FOCUSED" ] && exit 0 # focused pill is already lit
  sketchybar --animate tanh 30 --set "$NAME" background.border_color="$GLOW_RING"
  ;;
mouse.exited)
  if [ "$NAME" = "space.$FOCUSED" ]; then
    sketchybar --set "$NAME" background.border_color="$GLOW_EDGE"
  else
    sketchybar --animate tanh 30 --set "$NAME" background.border_color="$HAIRLINE"
  fi
  ;;
esac
