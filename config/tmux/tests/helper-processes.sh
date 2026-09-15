#!/usr/bin/env bash
# Run with: bash config/tmux/tests/helper-processes.sh
# (brew bash is needed for the unicode test literals below; the helpers under
# test keep /bin/bash 3.2 shebangs.)
#
# Regression checks for the scoped subprocess reductions in bin/nerdwin and
# bin/tmux-session-mood:
#   - nerdwin CLI vs. sourced-function icon parity
#   - nerdwin external-process counts (fixed icons fork nothing; only shell and
#     unknown commands query tmux)
#   - tmux-session-mood no longer forks awk/cut, and its output is unchanged
# Everything runs against a throwaway tmux server and stub commands on a
# private PATH; live tmux and user settings are never touched.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
mkdir -p "${TMPDIR:-/tmp}/claude-tmux-sockets"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/claude-tmux-sockets/helpers.XXXXXX")
SOCKET="$WORK/tmux.sock"
trap 'tmux -S "$SOCKET" kill-server 2>/dev/null || true; rm -rf "$WORK"' EXIT
trap 'echo "Failed at line $LINENO: $BASH_COMMAND" >&2' ERR

CALLS="$WORK/calls"
STUB="$WORK/stub"        # stub tmux, for nerdwin process counts
STUB_AC="$WORK/stub-ac"  # stub awk/cut only, real tmux stays reachable
mkdir -p "$STUB" "$STUB_AC"
# A stub tmux that answers @tmux-nerd-font-window-name-* like a bare server:
# every option is unset, so nerdwin uses its defaults. Each call is logged.
cat >"$STUB/tmux" <<EOF
#!/bin/bash
echo tmux >>"$CALLS"
exit 0
EOF
# Stub awk/cut only exist to prove tmux-session-mood never forks them.
for tool in awk cut; do
  cat >"$STUB_AC/$tool" <<EOF
#!/bin/bash
echo $tool >>"$CALLS"
exit 0
EOF
done
chmod +x "$STUB"/* "$STUB_AC"/*

count() { local n=0; [[ -f $CALLS ]] && n=$(grep -c "^$1\$" "$CALLS" || true); echo "$n"; }
reset_calls() { : >"$CALLS"; }

# --- nerdwin: CLI vs sourced-function parity, and no output while sourcing ---
reset_calls
sourced_out=$(PATH="$STUB:$PATH" /bin/bash -c 'source "$1"; echo done' _ "$ROOT/bin/nerdwin")
[[ $sourced_out == done && $(count tmux) -eq 0 ]]

for cmd in pi claude fleet node python bash weirdcmd tmux; do
  cli=$(PATH="$STUB:$PATH" "$ROOT/bin/nerdwin" "$cmd")
  fn=$(PATH="$STUB:$PATH" /bin/bash -c 'source "$1"; nerdwin "$2"' _ "$ROOT/bin/nerdwin" "$cmd")
  [[ $cli == "$fn" ]]
done
# Exact glyphs catch accidental deletion of private-use characters, which a
# CLI/function parity check alone cannot detect.
commands=(tmux top bash nvim git ruby go lf beam rustc python3)
icons=($'\xee\xaf\x88' $'\xee\xae\xa2' $'\xee\x9e\x95' $'\xee\x98\xab' $'\xee\x9c\x82' $'\xee\x88\xbe' $'\xee\x9c\xa4' $'\xef\x81\xbc' $'\xee\x9e\xb1' $'\xee\x9e\xa8' $'\xee\x9c\xbc')
for i in "${!commands[@]}"; do
  [[ $(PATH="$STUB:$PATH" "$ROOT/bin/nerdwin" "${commands[i]}") == "${icons[i]}" ]]
done
[[ $("$ROOT/bin/nerdwin" pi) == "π" ]]
[[ $("$ROOT/bin/nerdwin" weirdcmd) == "weirdcmd" ]]  # unknown, show-name unset

# --- nerdwin: external-process counts with a stub tmux on the PATH ---
np() { PATH="$STUB:$PATH" /bin/bash -c 'source "$1"; nerdwin "$2"' _ "$ROOT/bin/nerdwin" "$1" >/dev/null; }

reset_calls; np pi;       [[ $(count tmux) -eq 0 ]]  # fixed icon: zero externals
reset_calls; np claude;   [[ $(count tmux) -eq 0 ]]
reset_calls; np node;     [[ $(count tmux) -eq 0 ]]
reset_calls; np bash;     [[ $(count tmux) -eq 1 ]]  # shell icon lookup only
reset_calls; np weirdcmd; [[ $(count tmux) -eq 1 ]]  # show-name lookup only

echo "nerdwin: CLI/source parity and process counts passed"

# --- tmux-session-mood: real isolated server, but awk/cut must stay unforked ---
export HOME="$WORK/home"
mkdir -p "$HOME"
HOME=$(cd -P "$HOME" && pwd -P) # tmux reports physical paths on macOS
unset TMUX
tmux -S "$SOCKET" -f /dev/null new-session -d -s alpha 'sleep 300'
printf 'Temporary test server: tmux -S %q attach -t alpha\n' "$SOCKET"
tmux -S "$SOCKET" new-session -d -s beta 'sleep 300'
tmux -S "$SOCKET" new-session -d -s 'a#b' 'sleep 300'
TMUX=$(tmux -S "$SOCKET" display-message -p '#{socket_path},#{pid},0')
export TMUX

plain() { sed 's/#\[[^]]*\]//g'; }
mood() { PATH="$STUB_AC:$PATH" "$ROOT/bin/tmux-session-mood" "$@"; }

reset_calls
current=$(mood current alpha 1)
crest=$(mood crest alpha)
others=$(mood others alpha)
hashname=$(mood current 'a#b')
[[ $(count awk) -eq 0 && $(count cut) -eq 0 ]]  # builtins replaced the forks

# Output shape is preserved: default reset, hashed colour+sigil, bold name, ⧉.
[[ $current == '#[default]#[fg='*']'*' #[bold]alpha ⧉#[default]' ]]
[[ $(plain <<<"$current") == *'alpha ⧉' ]]
[[ $crest == '#[fg='*']'*' ' ]]
[[ $others == *'#[range=user|sess-beta]'* && $others != *'sess-alpha]'* ]]
[[ $hashname == *'a##b'* ]]  # literal # doubled for tmux

echo "tmux-session-mood: no awk/cut forks and output preserved"

# Exercise the batch against real tmux, including actual command parsing and
# rename-window's automatic-rename side effect. No personal config is loaded.
tmux set-option -g automatic-rename-format '#{window_name}'
window=$(tmux new-window -d -P -F '#{window_id}' -t alpha -n pending -c "$HOME" 'sleep 300')
tmux set-window-option -t "$window" automatic-rename on
for ((i = 0; i < 40; i++)); do
  [[ $(tmux display-message -p -t "$window" '#{pane_current_command}') == sleep ]] && break
  sleep 0.05
done
[[ $(tmux display-message -p -t "$window" '#{pane_current_command}') == sleep ]]
"$ROOT/bin/tmux-smart-name" --refresh
[[ $(tmux display-message -p -t "$window" '#{window_name}|#{automatic-rename}') == 'sleep ~|1' ]]
tmux rename-window -t "$window" 'manual name'
tmux set-option -g @smart_name_next 0
"$ROOT/bin/tmux-smart-name" --refresh
[[ $(tmux display-message -p -t "$window" '#{window_name}|#{automatic-rename}') == 'manual name|0' ]]
echo "Batched naming: real tmux rename, opt-in restoration and manual-name preservation passed"
echo "Helper process checks passed. Temporary test server cleaned up on exit."
