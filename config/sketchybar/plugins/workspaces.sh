#!/usr/bin/env bash
# Single-pass renderer for ALL workspace pills + their focus rings + the
# center module (window title, layout badge), run from the invisible
# spaces_controller item. Three aerospace queries + one batched sketchybar
# call per event — per-pill spawning is the documented lag/flicker trap
# (SketchyBar #726, AeroSpace #430). Needs bash 4+ (brew bash) for the
# associative arrays.
#
# FOCUSED_WORKSPACE is set by the aerospace_workspace_change trigger;
# on focus-change events and startup it's empty, so ask aerospace.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icons.sh"

STATE_DIR="$HOME/.cache/sketchybar"
mkdir -p "$STATE_DIR"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
# Read by space_hover.sh (restore-after-hover) and agents.sh (suppression)
echo "$FOCUSED" >"$STATE_DIR/focused-workspace"

declare -A APPS SEEN
while IFS='|' read -r ws app; do
  [ -n "$ws" ] || continue
  if [ -z "${SEEN[$ws|$app]:-}" ]; then
    SEEN[$ws|$app]=1
    APPS[$ws]+="$(app_icon "$app") "
  fi
done < <(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)

args=()
for sid in $(aerospace list-workspaces --all); do
  icons="${APPS[$sid]:-}"
  icons="${icons% }"
  if [ "$sid" = "$FOCUSED" ]; then
    # Bright inner stroke on the pill + dim outer ring on its bracket:
    # the glow falloff of the JankyBorders treatment, in two honest 1px lines
    args+=(--set "space.$sid" drawing=on
      background.drawing=on background.color="$GLOW_FILL"
      background.border_color="$GLOW_EDGE"
      icon.color="$GLOW_FULL" label.color="$GLOW_FULL"
      label="$icons" label.drawing="$([ -n "$icons" ] && echo on || echo off)"
      --set "ring.$sid" background.border_color="$GLOW_RING")
  elif [ -n "$icons" ]; then
    args+=(--set "space.$sid" drawing=on
      background.drawing=on background.color="$PILL_BG"
      background.border_color="$HAIRLINE"
      icon.color="$GREY" label.color="$FG"
      label="$icons" label.drawing=on
      --set "ring.$sid" background.border_color="$TRANSPARENT")
  else
    args+=(--set "space.$sid" drawing=off
      --set "ring.$sid" background.border_color="$TRANSPARENT")
  fi
done

# Center module: focused-window title.
# Agent panes title their windows "<state-glyph> <task summary>", so the
# center line reads as the current agent's task, prefixed with a robot
# state LED: green = working (braille spinner prefix), yellow =
# idle/awaiting (✳ prefix). Ordinary windows get no icon — the title
# floats alone. The state prefix and the 󱙺 window glyph are stripped for
# display (Monaspace lacks the glyph; byte prefixes matched raw since the
# daemon locale may be C).
RAW=$(aerospace list-windows --focused --format '%{window-title}' 2>/dev/null | head -1)
IS_AGENT=0
LED_COLOR="$ACCENT"
case "$RAW" in
"$(printf '\xe2\x9c\xb3')"*) # ✳ idle/awaiting
  IS_AGENT=1 LED_COLOR="$YELLOW" ;;
"$(printf '\xe2\xa0')"* | "$(printf '\xe2\xa1')"* | \
  "$(printf '\xe2\xa2')"* | "$(printf '\xe2\xa3')"*) # ⠂ working
  IS_AGENT=1 LED_COLOR="$GREEN" ;;
esac
# Strip the leading state glyph and ALL private-use-area chars (nerd font
# icons like the tmux 󱙺 — Monaspace renders them as boxed ?). Codepoint
# ranges instead of glyph literals: raw PUA bytes don't survive edits.
TITLE=$(perl -CS -pe 's/^[^A-Za-z0-9]+ *//; s/[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}] *//g' <<<"$RAW")
ROBOT=$(printf '\xf3\xb0\x9a\xa9') # nf-md-robot U+F06A9
if [ -n "$TITLE" ]; then
  if [ "$IS_AGENT" -eq 1 ]; then
    args+=(--set title drawing=on label="$TITLE"
      icon.drawing=on icon="$ROBOT" icon.color="$LED_COLOR")
  else
    args+=(--set title drawing=on label="$TITLE" icon.drawing=off)
  fi
else
  args+=(--set title drawing=off)
fi

sketchybar --animate tanh 10 "${args[@]}"
