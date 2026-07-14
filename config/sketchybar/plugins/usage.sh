#!/usr/bin/env bash
# Claude account rate-limit pill. Data is PUSHED by bin/claude-statusline,
# which tees the rate_limits stdin field to ~/.cache/claude-usage.json and
# fires claude_usage_update. Hidden below 70% of the 5h window or when the
# cache is stale (>30min = no active Claude session feeding it).
# Phosphor: the chip's edge lights in the severity hue.

source "$CONFIG_DIR/colors.sh"

CACHE="$HOME/.cache/claude-usage.json"

hide() {
  sketchybar --set "$NAME" drawing=off
  exit 0
}

[ -f "$CACHE" ] || hide
NOW=$(date +%s)
MTIME=$(stat -f %m "$CACHE" 2>/dev/null || echo 0)
[ $((NOW - MTIME)) -gt 1800 ] && hide

USED=$(jq -r '.five_hour.used_percentage // empty' "$CACHE" 2>/dev/null)
RESET=$(jq -r '.five_hour.resets_at // empty' "$CACHE" 2>/dev/null)
[ -z "$USED" ] && hide
USED=$(printf '%.0f' "$USED")
[ "$USED" -lt 70 ] && hide

COLOR="$YELLOW" EDGE="$YELLOW_BORDER" FILL="$YELLOW_FILL"
[ "$USED" -ge 85 ] && COLOR="$ORANGE" EDGE="$ORANGE_BORDER" FILL="$ORANGE_FILL"
[ "$USED" -ge 95 ] && COLOR="$RED" EDGE="$RED_BORDER" FILL="$RED_FILL"

LEFT=""
if [ -n "$RESET" ] && [ "$RESET" -gt "$NOW" ]; then
  MINS=$(((RESET - NOW) / 60))
  if [ "$MINS" -ge 60 ]; then
    LEFT=" ↻$((MINS / 60))h$((MINS % 60))m"
  else
    LEFT=" ↻${MINS}m"
  fi
fi

sketchybar --animate tanh 15 --set "$NAME" drawing=on \
  label="5h ${USED}%${LEFT}" label.color="$COLOR" icon.color="$COLOR" \
  background.color="$FILL" background.border_color="$EDGE"
