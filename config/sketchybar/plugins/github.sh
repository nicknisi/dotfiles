#!/usr/bin/env bash
# Open PRs awaiting my review, with a dropdown of the PRs themselves.
# Left-click toggles the dropdown (github_click.sh); right-click opens the
# pulls page; mouse.exited.global dismisses. Rows open their own PR.
# De-oranged: neutral icon always — a standing count of 20+ reviews is a
# fact of life, not an alarm. The count itself turns yellow past the
# threshold so magnitude still registers without crying wolf.
# Uses the search API (rate limit 30/min) — keep update_freq >= 120s.

source "$CONFIG_DIR/colors.sh"

THRESHOLD=15
SLOTS=10 # pre-allocated in sketchybarrc as github.popup.0..9

# Dismissal event — close the popup without burning a search API call.
if [ "$SENDER" = "mouse.exited.global" ]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi

# limit=30 keeps the count honest past the 10 visible rows
PRS=$(gh search prs --review-requested=@me --state=open --json title,url,repository --limit 30 2>/dev/null)
COUNT=$(jq 'length' <<<"$PRS" 2>/dev/null)

if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

LABEL_COLOR="$FG"
[ "$COUNT" -ge "$THRESHOLD" ] && LABEL_COLOR="$YELLOW"

ARGS=(--animate tanh 15 --set "$NAME" drawing=on
  label="$COUNT" label.color="$LABEL_COLOR" icon.color="$FG")

i=0
while IFS=$'\t' read -r REPO TITLE URL; do
  if [ "$i" -eq $((SLOTS - 1)) ] && [ "$COUNT" -gt "$SLOTS" ]; then
    # Last slot summarizes the overflow instead of showing a 10th PR
    ARGS+=(--set "$NAME.popup.$i" drawing=on icon=→
      label="+$((COUNT - i)) more  ·  open all" \
      click_script="open https://github.com/pulls/review-requested; sketchybar --set github popup.drawing=off")
    break
  fi
  ARGS+=(--set "$NAME.popup.$i" drawing=on label="$REPO: $TITLE"
    click_script="open '$URL'; sketchybar --set github popup.drawing=off")
  i=$((i + 1))
done < <(jq -r '.[] | [.repository.name, .title, .url] | @tsv' <<<"$PRS")

# Park the slots this render didn't use
for ((j = i; j < SLOTS; j++)); do
  ARGS+=(--set "$NAME.popup.$j" drawing=off)
done

sketchybar "${ARGS[@]}"
