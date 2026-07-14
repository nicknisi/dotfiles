#!/usr/bin/env bash
# Open PRs awaiting my review. Hidden at inbox-zero; click opens GitHub.
# De-oranged: neutral icon always — a standing count of 20+ reviews is a
# fact of life, not an alarm. The count itself turns yellow past the
# threshold so magnitude still registers without crying wolf.
# Uses the search API (rate limit 30/min) — keep update_freq >= 120s.

source "$CONFIG_DIR/colors.sh"

THRESHOLD=15

COUNT=$(gh search prs --review-requested=@me --state=open --json number --jq 'length' 2>/dev/null)

if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

LABEL_COLOR="$FG"
[ "$COUNT" -ge "$THRESHOLD" ] && LABEL_COLOR="$YELLOW"

sketchybar --animate tanh 15 --set "$NAME" drawing=on \
  label="$COUNT" label.color="$LABEL_COLOR" icon.color="$FG"
