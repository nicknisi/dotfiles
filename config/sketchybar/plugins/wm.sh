#!/usr/bin/env bash
# Small shared bridge: numeric OmniWM IDs stay separate from display labels.
# SKETCHYBAR_WM can pin a backend; otherwise prefer the running OmniWM.
if [ -z "${SKETCHYBAR_WM:-}" ]; then
  if pgrep -xq OmniWM; then SKETCHYBAR_WM=omniwm; else SKETCHYBAR_WM=aerospace; fi
fi
OMNIWMCTL="${OMNIWMCTL:-$(command -v omniwmctl || printf '%s' /Applications/OmniWM.app/Contents/MacOS/omniwmctl)}"

wm_workspaces() (
  set -o pipefail
  if [ "$SKETCHYBAR_WM" = omniwm ]; then
    "$OMNIWMCTL" query workspaces --fields number,display-name --format json |
      jq -er '.result.payload.workspaces[] | "\(.number)|\(.displayName // .number)"'
  else
    aerospace list-workspaces --all | while IFS= read -r sid; do printf '%s|%s\n' "$sid" "$sid"; done
  fi
)

wm_focus() {
  if [ "$SKETCHYBAR_WM" = omniwm ]; then
    "$OMNIWMCTL" command switch-workspace "$1" >/dev/null
  else
    aerospace workspace "$1"
  fi
}

# Existing widgets navigate by purpose (D / W), not by OmniWM's numbers.
wm_focus_label() {
  local rows sid label
  rows=$(wm_workspaces) || return 1
  while IFS='|' read -r sid label; do
    if [ "$label" = "$1" ]; then wm_focus "$sid"; return; fi
  done <<<"$rows"
  printf 'Unknown workspace label: %s\n' "$1" >&2
  return 1
}

wm_stop_watch() {
  # Anchor the executable: an unanchored match also kills shells whose
  # command text merely mentions this subscription (e.g. verification scripts).
  pkill -f '^([^ ]*/)?omniwmctl watch .*--exec sketchybar --trigger omniwm_change$' 2>/dev/null || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    focus) wm_focus "$2" ;;
    focus-label) wm_focus_label "$2" ;;
    watch)
      exec "$OMNIWMCTL" watch focus,active-workspace,windows-changed,display-changed,layout-changed \
        --reconnect --exec sketchybar --trigger omniwm_change
      ;;
    watchdog)
      if ! pgrep -xq OmniWM && ! pgrep -xq AeroSpace; then
        wm_stop_watch
        pkill -f 'fswatch.*claude-status' 2>/dev/null || true
        pkill -x sketchybar
      fi
      ;;
  esac
fi
