#!/usr/bin/env bash
# Agents pill + attention chip, rendered together in one batched call.
#
# WAITING comes from fleet's hook-written status files
# (~/.cache/{claude,codex,pi}-status/<pane>.status — ~37ms via jq), the
# same ground truth fleet's own TUI watches. TOTAL still comes from pane
# process names (codex/pi don't write status files yet).
# Push updates: fleet_state_change (fswatch via bin/sketchybar-fleet-watch);
# update_freq=60 on the item is only a reconcile backstop.
#
# Phosphor visual language: calm = dim green robot (healthy, unlit edge);
# an alert lights its border in the tier hue rather than shouting.
# Tiers mirror fleet: permit > question > done.

source "$CONFIG_DIR/colors.sh"

STATE_DIR="$HOME/.cache/sketchybar"
mkdir -p "$STATE_DIR"

PANES=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)
TOTAL=$(tmux list-panes -a -F '#{pane_current_command}' 2>/dev/null |
  grep -cE '^([0-9]+\.[0-9]+\.[0-9]+$|claude|codex|pi$)')

if [ "${TOTAL:-0}" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off --set attention drawing=off
  exit 0
fi

# Waiting rows as "state|pane|session|tool", priority-sorted, orphans dropped
ROWS=$(cat "$HOME"/.cache/{claude,codex,pi}-status/*.status 2>/dev/null |
  jq -r 'select(.state == "permit" or .state == "question" or .state == "done")
    | "\(.state)|\(.pane)|\(.session)|\(.tool)"' 2>/dev/null |
  while IFS= read -r row; do
    pane="${row#*|}" pane="${pane%%|*}"
    grep -qx -- "$pane" <<<"$PANES" && echo "$row"
  done |
  awk -F'|' '{p = ($1=="permit") ? 0 : ($1=="question") ? 1 : 2; print p "|" $0}' |
  sort -t'|' -k1,1n | cut -d'|' -f2-)

WAITING=0
[ -n "$ROWS" ] && WAITING=$(wc -l <<<"$ROWS" | tr -d ' ')

# Tier rank for escalation detection (0 none, 1 done, 2 question, 3 permit)
RANK=0
case "$(head -1 <<<"$ROWS" | cut -d'|' -f1)" in
permit) RANK=3 ;; question) RANK=2 ;; done) RANK=1 ;;
esac
PREV_RANK=$(cat "$STATE_DIR/agents-rank" 2>/dev/null || echo 0)
echo "$RANK" >"$STATE_DIR/agents-rank"

# Easter egg: the moment the last waiting agent is handled
PREV=$(cat "$STATE_DIR/agents-waiting" 2>/dev/null || echo 0)
echo "$WAITING" >"$STATE_DIR/agents-waiting"
if [ "$WAITING" -eq 0 ] && [ "${PREV:-0}" -gt 0 ]; then
  sketchybar --animate tanh 20 --set "$NAME" drawing=on \
    icon="✓" icon.color="$GREEN" label="vibes: immaculate" label.color="$GREEN" \
    background.border_color="$GREEN_BORDER" background.color="$GREEN_FILL"
  sleep 2
fi

# On the terminal workspace tmux's own statusline already shows all of
# this — keep the pill quiet and drop the chip instead of shouting twice.
SUPPRESS=0
[ "$(cat "$STATE_DIR/focused-workspace" 2>/dev/null)" = "D" ] && SUPPRESS=1

ROBOT=$(printf '\xf3\xb0\x9a\xa9') # nf-md-robot U+F06A9

if [ "$WAITING" -gt 0 ] && [ "$SUPPRESS" -eq 0 ]; then
  TOP=$(head -1 <<<"$ROWS")
  IFS='|' read -r STATE PANE SESSION TOOL <<<"$TOP"
  case "$STATE" in
  permit) GLYPH="⚠" COLOR="$YELLOW" EDGE="$YELLOW_BORDER" FILL="$YELLOW_FILL" ;;
  question) GLYPH="?" COLOR="$MAGENTA" EDGE="$MAGENTA_BORDER" FILL="$MAGENTA_FILL" ;;
  *) GLYPH="●" COLOR="$GREEN" EDGE="$GREEN_BORDER" FILL="$GREEN_FILL" ;;
  esac

  # Task title from the pane title (leading ✳/spinner glyph = Claude's
  # state prefix), falling back to fleet's tool field.
  TASK=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null |
    sed -E 's/^[^A-Za-z0-9]+ *//')
  [ -z "$TASK" ] && TASK="$TOOL"

  sketchybar --animate tanh 15 \
    --set "$NAME" drawing=on icon="$GLYPH" icon.color="$COLOR" \
    label="$WAITING/$TOTAL" label.color="$COLOR" \
    background.color="$FILL" background.border_color="$EDGE" \
    --set attention drawing=on icon="$GLYPH" icon.color="$COLOR" \
    label="$SESSION: $TASK" label.color="$COLOR" \
    background.color="$FILL" background.border_color="$EDGE" \
    click_script="aerospace workspace D; fleet switch $PANE"

  # Escalation bounce: only when the top tier got MORE urgent
  if [ "$RANK" -gt "${PREV_RANK:-0}" ]; then
    sketchybar --animate tanh 15 --set "$NAME" y_offset=4 y_offset=0
  fi
else
  # Calm: dim green robot = fleet healthy; unlit edge, muted count.
  # (Suppressed-but-waiting on D keeps fg text so it's readable up close.)
  COLOR="$CALM_GREEN"
  COUNT_COLOR="$GREY"
  [ "$WAITING" -gt 0 ] && COUNT_COLOR="$FG"
  sketchybar --animate tanh 15 \
    --set "$NAME" drawing=on icon="$ROBOT" icon.color="$COLOR" \
    label="$TOTAL" label.color="$COUNT_COLOR" \
    background.color=0x8010161f background.border_color="$TRANSPARENT" \
    --set attention drawing=off
fi
