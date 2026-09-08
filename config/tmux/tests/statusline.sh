#!/usr/bin/env bash
# Run with: bash config/tmux/tests/statusline.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
mkdir -p "${TMPDIR:-/tmp}/claude-tmux-sockets"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/claude-tmux-sockets/statusline.XXXXXX")
SOCKET="$WORK/tmux.sock"
trap 'tmux -S "$SOCKET" kill-server 2>/dev/null || true; rm -rf "$WORK"' EXIT
trap 'echo "Failed at line $LINENO: $BASH_COMMAND" >&2' ERR

# No personal config, shell startup, fleet jobs or palette changes.
export HOME="$WORK/home"
mkdir -p "$HOME/.local/state/theme/current"
unset TMUX
tmux -S "$SOCKET" -f /dev/null new-session -d -s projects -n dotfiles 'sleep 300'
printf 'Temporary test server: tmux -S %q attach -t projects\n' "$SOCKET"
TMUX=$(tmux -S "$SOCKET" display-message -p '#{socket_path},#{pid},0')
export TMUX
tmux set-option -g base-index 1
tmux move-window -s projects:0 -t projects:1
tmux new-window -d -t projects:2 -n editor 'sleep 300'
tmux new-session -d -s review 'sleep 300'

plain() { sed 's/#\[[^]]*\]//g'; }
for mode in dark light; do
  printf '%s\n' "$mode" > "$HOME/.local/state/theme/current/mode"
  bash "$ROOT/config/tmux/theme/theme.tmux"
  orange=$(tmux show-option -gqv @thm_sl_orange)
  blue=$(tmux show-option -gqv @thm_sl_blue)
  cyan=$(tmux show-option -gqv @thm_sl_cyan)
  dim=$(tmux show-option -gqv @thm_sl_dim)

  # The original hash gives projects an orange ✧, now as text rather than a pill.
  current=$("$ROOT/bin/tmux-session-mood" current projects 1)
  [[ $current == "#[default]#[fg=$orange]✧ #[bold]projects ⧉#[default]" ]]
  [[ $("$ROOT/bin/tmux-session-mood" pill projects 1) == "$current" ]]
  [[ $("$ROOT/bin/tmux-session-mood" current 'a#b') == *'a##b'* ]]
  others=$("$ROOT/bin/tmux-session-mood" others projects)
  [[ $others == *'#[range=user|sess-review]'* && $others != *'sess-projects]'* ]]
  [[ $others == *"#[fg=$dim]review"* ]]

  active=$(tmux display-message -p -t projects:1 '#{E:window-status-current-format}')
  idle=$(tmux display-message -p -t projects:1 '#{E:window-status-format}')
  second=$(tmux display-message -p -t projects:2 '#{E:window-status-format}')
  [[ $(plain <<<"$active") == ' ➊ dotfiles ' && $active == *"#[fg=$blue]"* ]]
  [[ $(plain <<<"$idle") == ' ➀ dotfiles ' && $idle == *"#[fg=$dim]"* ]]
  [[ $(plain <<<"$second") == ' ➁ editor ' && $second == *"#[fg=$cyan]"* ]]
  [[ $(tmux show-option -gqv window-status-separator) == '  ' ]]

  # Exercise the prefix branch without needing an attached keyboard client.
  left=$(tmux show-option -gqv status-left)
  tmux set-option -g @test_prefix 1
  prefix=$(tmux display-message -p -t projects:1 "${left//client_prefix/@test_prefix}")
  [[ $(plain <<<"$prefix") == $'  \U000f140b projects   ' ]]
  tmux set-option -gu @test_prefix

  for state_glyph in 'yellow ⚠' 'magenta ?' 'green ●'; do
    read -r state glyph <<<"$state_glyph"
    tmux set-option -w -t projects:1 @fleet_state "$state"
    [[ $("$ROOT/bin/tmux-session-mood" current projects | plain) == "$glyph projects" ]]
    [[ $(tmux display-message -p -t projects:1 '#{E:window-status-current-format}') == *"#[fg=$state]"* ]]
  done
  tmux set-option -w -t review:1 @fleet_state magenta
  [[ $("$ROOT/bin/tmux-session-mood" others projects) == *'#[fg=magenta]? '* ]]
  tmux set-option -wu -t projects:1 @fleet_state
  tmux set-option -wu -t review:1 @fleet_state
  [[ $("$ROOT/bin/tmux-session-mood" current projects 1) == "$current" ]]

  tmux copy-mode -t projects:1.0
  right=$(tmux display-message -p -t projects:1 '#{E:status-right}')
  [[ $right == *'◈ copy'* ]]
  tmux send-keys -t projects:1.0 -X cancel
  [[ $(tmux display-message -p -t projects:1 '#{E:status-right}') != *'◈ copy'* ]]

  # No pill backgrounds, half-circle caps, underlines or mascot remain.
  for format in "$current" "$others" "$active" "$idle" "$prefix" "$right"; do
    [[ $format != *'bg='* && $format != *'underscore'* && $format != *'▗'* ]]
    [[ $format != *$'\ue0b6'* && $format != *$'\ue0b4'* ]]
  done
  printf '%s palette: original crests, digits, prefix, fleet and copy mode passed without pills\n' "$mode"
done

# Indices beyond the original ten-glyph lookup table still fall back to digits.
tmux new-window -d -t projects:12 -n terminal 'sleep 300'
[[ $(tmux display-message -p -t projects:12 '#{E:window-status-current-format}' | plain) == ' 12 terminal ' ]]
printf 'Statusline checks passed. Temporary test server cleaned up on exit.\n'
