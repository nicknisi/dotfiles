#!/usr/bin/env bash
# bin/shell-lock against a fake qs and a fake hyprlock on PATH (PLAN M8):
# it exits 0 once the lock answers secure, falls back to hyprlock when the
# lock never does (stopping it first) or dies early, and starts nothing when a
# lock already answers. Two runs at once start one lock and no fallback. Its
# watcher relaunches a lock that died locked, leaves one that marked its
# unlock, and gives up to hyprlock after 3 relaunches. No real Quickshell,
# compositor or lock is involved.
#
# The "hyprlock already running" branch (pgrep -u <uid> -x hyprlock) is not exercised:
# a process named hyprlock on the live machine would make hypridle skip a lock
# while it runs. .shell-rebuild/specs/shots/M8/lock-test.sh covers the real
# thing inside a sandbox Hyprland.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
# Watchers first (killing a lock under a watcher relaunches it), then locks.
stop_all() {
  pkill -f "shell-lock --watch [0-9]+ $TMP/" 2>/dev/null || true
  pkill -f "$TMP/bin/qs" 2>/dev/null || true
  sleep 0.2
}
cleanup() {
  stop_all
  rm -rf -- "$TMP"
}
trap cleanup EXIT
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/rt"

cat >"$TMP/bin/qs" <<'EOF'
#!/usr/bin/env bash
# Fake qs. `ipc ... call lock secure` counts polls and answers true once the
# instance runs and FAKE_QS_SECURE_AT polls have passed (or always, with
# $state/presecure). Anything else is the instance: it records its arguments
# and SHELL_LOCK_DONE and runs until TERM, or exits at once with
# FAKE_QS_MODE=die, or when one already runs (qs -n).
state=$FAKE_QS_STATE
if [ "${1:-}" = ipc ]; then
  echo "$*" >>"$state/ipc"
  case "$*" in
    *"call lock inspect"*)
      [ -f "$state/noipc" ] && exit 0
      if [ -f "$state/running" ]; then
        if [ -f "$state/unlocked" ]; then echo '{"locked":false}'; else echo '{"locked":true}'; fi
      fi
      exit 0 ;;
  esac
  n=$(cat "$state/polls" 2>/dev/null || echo 0)
  n=$((n + 1))
  echo "$n" >"$state/polls"
  if [ -f "$state/presecure" ]; then echo true; exit 0; fi
  if [ -f "$state/running" ] && [ -n "${FAKE_QS_SECURE_AT:-}" ] && [ "$n" -ge "$FAKE_QS_SECURE_AT" ]; then
    echo true
  else
    echo false
  fi
  exit 0
fi
echo "$*" >"$state/args"
echo start >>"$state/starts"
echo "${SHELL_LOCK_DONE:-}" >"$state/done-path"
[ "${FAKE_QS_MODE:-}" = die ] && exit 1
[ -f "$state/running" ] && exit 1
touch "$state/running"
trap 'rm -f "$state/running"; echo TERM >"$state/signal"; exit 0' TERM
while :; do sleep 0.05; done
EOF
cat >"$TMP/bin/hyprlock" <<'EOF'
#!/usr/bin/env bash
echo "hyprlock $*" >"$FAKE_QS_STATE/hyprlock"
EOF
chmod +x "$TMP/bin/qs" "$TMP/bin/hyprlock"
touch "$TMP/lock.qml"

fail() { echo "SHELL_LOCK_TEST_FAIL: $*" >&2; exit 1; }

# run NAME [ENV=VAL...]: shell-lock with the fakes, from a clean state.
run() {
  local name=$1
  shift
  rm -rf "$TMP/state"
  mkdir -p "$TMP/state"
  [ "${PRESECURE:-0}" = 1 ] && touch "$TMP/state/presecure"
  set +e
  env PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP" FAKE_QS_STATE="$TMP/state" XDG_RUNTIME_DIR="$TMP/rt" \
    SHELL_LOCK_QML="$TMP/lock.qml" SHELL_LOCK_WAIT=6 SHELL_LOCK_WATCH=0.1 SHELL_LOCK_LOG="$TMP/watch.log" "$@" \
    bash "$ROOT/bin/shell-lock" >"$TMP/out" 2>&1
  code=$?
  set -e
  echo "-- $name: exit $code"
}

# Locks: the instance answers secure on the third poll.
run "secure" FAKE_QS_SECURE_AT=3
[ "$code" = 0 ] || fail "secure lock should exit 0 ($(cat "$TMP/out"))"
[ ! -f "$TMP/state/hyprlock" ] || fail "no fallback when the lock is secure"
grep -q -- "-n -p $TMP/lock.qml" "$TMP/state/args" || fail "starts qs -n -p <lock.qml>: $(cat "$TMP/state/args")"
grep -q "ipc -p $TMP/lock.qml call lock secure" "$TMP/state/ipc" || fail "asks lock secure"
[ -f "$TMP/state/running" ] || fail "the lock keeps running after shell-lock exits"
done_path=$(cat "$TMP/state/done-path")
case "$done_path" in "$TMP/rt/shell-lock."*.unlocked) ;; *) fail "the lock gets an unlock mark under XDG_RUNTIME_DIR: $done_path" ;; esac
[ ! -e "$done_path" ] || fail "the unlock mark does not exist before an unlock"
pgrep -f "shell-lock --watch [0-9]+ $done_path" >/dev/null || fail "a watcher stays behind"

# wait_for COND SECONDS: COND (a shell expression) turns true in time.
wait_for() {
  local n=0
  while [ "$n" -lt $(($2 * 10)) ]; do
    eval "$1" && return 0
    sleep 0.1
    n=$((n + 1))
  done
  return 1
}
starts() { wc -l <"$TMP/state/starts" | tr -d ' '; }

# The lock dies locked (no unlock mark): the watcher starts a new one.
pkill -TERM -f "$TMP/bin/qs -n" 2>/dev/null || true
wait_for '[ "$(starts)" = 2 ] && [ -f "$TMP/state/running" ]' 4 || fail "the watcher relaunches a lock that died locked (starts $(starts))"
grep -q "died while locked; starting a new one" "$TMP/watch.log" || fail "the watcher says why: $(cat "$TMP/watch.log")"
[ ! -f "$TMP/state/hyprlock" ] || fail "a relaunch, not the fallback"
done2=$(cat "$TMP/state/done-path")
[ "$done2" != "$done_path" ] || fail "each lock gets its own unlock mark"
wait_for 'pgrep -f "shell-lock --watch [0-9]+ $done2" >/dev/null' 3 || fail "the relaunched lock has its own watcher"

# A real unlock: lock.qml creates the mark, then ends. Nothing relaunches.
touch "$done2"
pkill -TERM -f "$TMP/bin/qs -n" 2>/dev/null || true
sleep 1.2
[ "$(starts)" = 2 ] || fail "no relaunch after a marked unlock (starts $(starts))"
[ ! -e "$done2" ] || fail "the watcher removes the mark"
pgrep -f "shell-lock --watch [0-9]+ $TMP/" >/dev/null && fail "the watcher ends with the lock"
stop_all

# The third relaunch in a row: hyprlock instead.
: >"$TMP/watch.log"
run "relaunch cap" FAKE_QS_SECURE_AT=3 SHELL_LOCK_RELAUNCH=3
[ "$code" = 0 ] || fail "the capped chain still locks first ($(cat "$TMP/out"))"
pkill -TERM -f "$TMP/bin/qs -n" 2>/dev/null || true
wait_for '[ -f "$TMP/state/hyprlock" ]' 3 || fail "after 3 relaunches the watcher runs hyprlock"
[ "$(starts)" = 1 ] || fail "and starts no fourth lock (starts $(starts))"
grep -q "died while locked 3 times" "$TMP/watch.log" || fail "says why: $(cat "$TMP/watch.log")"
stop_all

# Two runs at once (SUPER+ESCAPE, then a lid close): the second's qs -n
# exits because the first's lock is still starting. It waits for that lock,
# starts no fallback, and both exit 0.
rm -rf "$TMP/state"
mkdir -p "$TMP/state"
both() {
  env PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP" FAKE_QS_STATE="$TMP/state" XDG_RUNTIME_DIR="$TMP/rt" \
    SHELL_LOCK_QML="$TMP/lock.qml" SHELL_LOCK_WAIT=20 SHELL_LOCK_WATCH=0.1 SHELL_LOCK_LOG="$TMP/watch.log" FAKE_QS_SECURE_AT=10 \
    bash "$ROOT/bin/shell-lock"
}
both >"$TMP/out1" 2>&1 &
first=$!
sleep 0.3
set +e
both >"$TMP/out2" 2>&1
code2=$?
wait "$first"
code1=$?
set -e
echo "-- overlap: exit $code1 and $code2"
[ "$code1" = 0 ] && [ "$code2" = 0 ] || fail "both runs exit 0 ($code1 $code2): $(cat "$TMP/out1" "$TMP/out2")"
[ ! -f "$TMP/state/hyprlock" ] || fail "no fallback races the lock: $(cat "$TMP/out2")"
[ "$(starts)" = 2 ] || fail "the second run tried once and was refused (starts $(starts))"
[ "$(pgrep -fc "$TMP/bin/qs -n")" = 1 ] || fail "one lock instance"
[ "$(pgrep -fc "shell-lock --watch [0-9]+ $TMP/")" = 1 ] || fail "one watcher, the first run's"
stop_all

# An instance left over after an unlock (it reports locked false) is no lock
# in progress: shell-lock's own qs -n is refused, and it falls back at once.
rm -rf "$TMP/state"
mkdir -p "$TMP/state"
touch "$TMP/state/unlocked"
FAKE_QS_STATE="$TMP/state" setsid bash "$TMP/bin/qs" -n -p "$TMP/lock.qml" --no-color >/dev/null 2>&1 &
sleep 0.3
set +e
env PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP" FAKE_QS_STATE="$TMP/state" XDG_RUNTIME_DIR="$TMP/rt" \
  SHELL_LOCK_QML="$TMP/lock.qml" SHELL_LOCK_WAIT=6 SHELL_LOCK_WATCH=0.1 SHELL_LOCK_LOG="$TMP/watch.log" \
  bash "$ROOT/bin/shell-lock" >"$TMP/out" 2>&1
code=$?
set -e
echo "-- leftover unlocked instance: exit $code"
[ -f "$TMP/state/hyprlock" ] || fail "a leftover unlocked instance is not a lock: falls back ($(cat "$TMP/out"))"
grep -q "exited before locking" "$TMP/out" || fail "says why: $(cat "$TMP/out")"
stop_all

# Another instance runs but never answers IPC and never commits: no exit 0
# on its say-so. shell-lock waits out the polls, then runs hyprlock itself.
rm -rf "$TMP/state"
mkdir -p "$TMP/state"
touch "$TMP/state/noipc"
FAKE_QS_STATE="$TMP/state" setsid bash "$TMP/bin/qs" -n -p "$TMP/lock.qml" --no-color >/dev/null 2>&1 &
sleep 0.3
set +e
env PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP" FAKE_QS_STATE="$TMP/state" XDG_RUNTIME_DIR="$TMP/rt" \
  SHELL_LOCK_QML="$TMP/lock.qml" SHELL_LOCK_WAIT=6 SHELL_LOCK_WATCH=0.1 SHELL_LOCK_LOG="$TMP/watch.log" \
  bash "$ROOT/bin/shell-lock" >"$TMP/out" 2>&1
code=$?
set -e
echo "-- silent pending instance: exit $code"
[ -f "$TMP/state/hyprlock" ] || fail "a lock that never commits is no lock: falls back ($(cat "$TMP/out"))"
grep -q "other lock screen did not report a committed lock" "$TMP/out" || fail "says why: $(cat "$TMP/out")"
stop_all

# A planted unlock mark (a symlink, not lock.qml's file) is no unlock: the
# watcher still relaunches a lock that died.
run "planted mark" FAKE_QS_SECURE_AT=3
[ "$code" = 0 ] || fail "locks first ($(cat "$TMP/out"))"
planted=$(cat "$TMP/state/done-path")
ln -s "$TMP/lock.qml" "$planted"
pkill -TERM -f "$TMP/bin/qs -n" 2>/dev/null || true
wait_for '[ "$(starts)" = 2 ] && [ -f "$TMP/state/running" ]' 4 || fail "a symlinked mark does not stop the relaunch (starts $(starts))"
rm -f "$planted"
stop_all

# No usable XDG_RUNTIME_DIR: no mark in a shared dir, straight to hyprlock.
run "no runtime dir" XDG_RUNTIME_DIR=
[ -f "$TMP/state/hyprlock" ] || fail "falls back without XDG_RUNTIME_DIR"
[ ! -f "$TMP/state/args" ] || fail "starts no lock without a private runtime dir"
grep -q "XDG_RUNTIME_DIR is not a directory" "$TMP/out" || fail "says why: $(cat "$TMP/out")"

# Never secure: the lock is stopped (TERM) and hyprlock takes over.
run "never secure"
[ "$code" = 0 ] || fail "the fallback's exit status ($code)"
[ -f "$TMP/state/hyprlock" ] || fail "falls back to hyprlock when the lock is never secure"
[ "$(cat "$TMP/state/signal" 2>/dev/null)" = TERM ] || fail "stops the lock before falling back"
[ "$(cat "$TMP/state/polls")" -ge 7 ] || fail "polls SHELL_LOCK_WAIT times plus the first check"
grep -q "did not report a committed lock" "$TMP/out" || fail "says why it fell back"
pgrep -f "shell-lock --watch [0-9]+ $TMP/" >/dev/null && fail "no watcher for a lock that never locked"
stop_all

# The instance dies at once: fall back without waiting out the polls.
run "dies" FAKE_QS_MODE=die
[ -f "$TMP/state/hyprlock" ] || fail "falls back when the lock exits"
grep -q "exited before locking" "$TMP/out" || fail "says the lock exited"

# Already locked by the Quickshell lock: nothing new starts.
PRESECURE=1 run "already secure"
PRESECURE=0
[ "$code" = 0 ] || fail "already locked exits 0"
[ ! -f "$TMP/state/args" ] || fail "starts no second lock"
[ ! -f "$TMP/state/hyprlock" ] || fail "no fallback when already locked"

# No lock config: straight to hyprlock.
run "no config" SHELL_LOCK_QML="$TMP/missing.qml"
[ -f "$TMP/state/hyprlock" ] || fail "falls back with no lock.qml"
[ ! -f "$TMP/state/args" ] || fail "starts no qs without a config"

# A custom fallback command with arguments.
run "fallback args" SHELL_LOCK_FALLBACK="hyprlock --immediate"
grep -q "hyprlock --immediate" "$TMP/state/hyprlock" || fail "runs SHELL_LOCK_FALLBACK with its arguments"

# Usage.
bash "$ROOT/bin/shell-lock" --help | grep -q "clear_crashed_lockscreen" || fail "--help documents TTY recovery"
bash "$ROOT/bin/shell-lock" --help | grep -q "Testing real PAM" || fail "--help has the real-PAM steps"
set +e
bash "$ROOT/bin/shell-lock" --bogus >/dev/null 2>&1
code=$?
set -e
[ "$code" = 2 ] || fail "unknown argument exits 2"

# Portable shell: no GNU timeout, no bashisms that macOS bash 3.2 rejects.
if grep -nE '\btimeout\b|\[\[|declare -A|readarray|mapfile' "$ROOT/bin/shell-lock" | grep -v '^\s*[0-9]*:\s*#'; then
  fail "shell-lock must stay plain bash with BSD tools"
fi

echo SHELL_LOCK_TEST_PASS
