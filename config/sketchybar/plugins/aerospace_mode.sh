#!/usr/bin/env bash
# AeroSpace binding-mode badge — the bar's one inverted chip: solid orange
# fill, dark text. Only visible outside 'main' mode; the trigger (fired
# from mode bindings in aerospace.toml) passes MODE=service|main.

source "$CONFIG_DIR/colors.sh"

if [ "${MODE:-main}" = "main" ]; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --animate tanh 30 --set "$NAME" drawing=on \
    label="$(echo "$MODE" | tr '[:lower:]' '[:upper:]')" \
    label.color="$INK" icon.color="$INK" \
    background.drawing=on background.color="$ORANGE" \
    background.border_width=0 \
    y_offset=4 y_offset=0
fi
