#!/usr/bin/env bash
# The sleep fade (SleepFade.qml, SleepWatch.qml, lib/SleepFade.js) in a real
# Quickshell, offscreen, against a fake logind (tests/fake-logind.sh: a fake
# gdbus monitor fed from a FIFO, a fake systemd-inhibit that logs), so
# nothing reaches the system bus, logind or the live session:
#
#   1. lib/SleepFade.js under node (tests/sleep-fade.cjs).
#   2. Awake: the inhibitor is held (systemd-inhibit --what=sleep
#      --mode=delay under setpriv's parent death signal), the overlay
#      unmapped.
#   3. PrepareForSleep(true) as gdbus prints it: closing, the overlay mapped
#      and taking the pointer, then closed with the inhibitor released
#      within the 1 s cap (400 ms fade).
#   4. PrepareForSleep(false): opening (black, the pointer through), the
#      inhibitor taken again at once, then open and unmapped.
#   5. A missed wake: still preparing after the watch's staleMs (10 s; 1.5 s
#      here) opens the screens and takes the inhibitor again, and the next
#      PrepareForSleep(true) fades and releases it again (it used to be
#      swallowed, and logind waited out InhibitDelayMaxSec).
#   6. The monitor dying mid-sleep opens the screens (never stuck black) and
#      lets the inhibitor go until it is back.
#   7. kill -9 of the shell: the inhibitor's process ends with it (stdin EOF
#      or the parent death signal), so logind would drop the lock.
#   8. The sandbox: `sleep prepare` drives the same machine, `sleep hold`
#      pins a level, and the inhibitor is a plain `cat`.
#   L. lock.qml, offscreen beside all that, started while the fake logind
#      says PreparingForSleep (hypridle's before_sleep_cmd path): its watch
#      settles on that first reading, the lock-in motion (due at the 1 s
#      arrive timer offscreen) waits for the wake (`held`), and after 10 s of
#      awake time with no wake signal (the real staleMs: lock.qml takes no
#      test knob) it comes back up and the next PrepareForSleep(true) counts
#      again. The main shell's mark (written while closing, 0 once opening):
#      a lock whose watch has no reading yet takes a fresh mark as asleep (it
#      starts black and holds its content), lets it go after 10 s if the
#      watch never reads, and ignores an old one. The night itself is
#      tst_lock_surface's (offscreen there are no lock surfaces).
# Keep TMPDIR short (check.sh's note): the IPC socket lives under it.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
qspid=""
lockpid=""
markpid=""
cleanup() {
    [ -n "$qspid" ] && kill -9 "$qspid" 2>/dev/null || true
    [ -n "$lockpid" ] && kill "$lockpid" 2>/dev/null || true
    [ -n "$markpid" ] && kill "$markpid" 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
    exec 8>&- 2>/dev/null || true
    pkill -f "$tmp/" 2>/dev/null || true
    rm -rf -- "$tmp"
}
trap cleanup EXIT
fail() {
    echo "SLEEP_FADE_SH_FAIL: $*" >&2
    [ -f "$tmp/qs.log" ] && tail -30 "$tmp/qs.log" >&2
    [ -f "$tmp/inhibit.log" ] && cat "$tmp/inhibit.log" >&2
    [ -f "$tmp/lock.log" ] && tail -20 "$tmp/lock.log" >&2
    exit 1
}

# ---- 1 ---------------------------------------------------------------------------
node "$root/tests/sleep-fade.cjs"

bash "$root/tests/fake-logind.sh" "$tmp/bin"
cfg="$tmp/cfg"
cp -R "$root" "$cfg"
rm -rf "$cfg/tests"
cat >"$cfg/shell.qml" <<'QML'
import Quickshell
import QtQuick
ShellRoot {
    // Offscreen has no layer shell: the machine, the listener and the
    // inhibitor only (the windows are the sandbox shots').
    SleepFade {
        overlay: false
        staleMs: 1500
    }
}
QML
rt="$tmp/rt"
mkdir -p "$rt"
chmod 700 "$rt"
fifo="$tmp/logind.fifo"
mkfifo "$fifo"
run_env=(env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SHELL_SANDBOX -u SBX_RUNTIME -u SHELL_DRY_RUN
    PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$rt" XDG_STATE_HOME="$tmp/state" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic
    FAKE_INHIBIT_LOG="$tmp/inhibit.log")
ipc() { "${run_env[@]}" qs ipc -p "$cfg" call sleep "$@"; }
field() { python3 -c 'import json,sys; v=json.loads(sys.argv[1]); print(json.dumps(v.get(sys.argv[2])))' "$1" "$2"; }
# wait_for EXPR: poll `sleep inspect` until a python expression on v holds.
wait_for() {
    local expr=$1 limit=${2:-40} out=""
    for _ in $(seq 1 "$limit"); do
        out=$(ipc inspect 2>/dev/null || true)
        if [ -n "$out" ] && python3 -c "import json,sys; v=json.loads(sys.argv[1]); sys.exit(0 if ($expr) else 1)" "$out"; then
            printf '%s\n' "$out"
            return 0
        fi
        sleep 0.05
    done
    fail "timed out waiting for $expr: $out"
}
start() {
    "${run_env[@]}" FAKE_LOGIND_FIFO="$fifo" qs -p "$cfg" --no-color >"$tmp/qs.log" 2>&1 &
    qspid=$!
    # Held open read-write (no wait for the fake monitor's cat to open it), so
    # the monitor never sees EOF between signals.
    exec 9<>"$fifo"
    for _ in $(seq 1 100); do
        grep -q 'Configuration Loaded' "$tmp/qs.log" && break
        grep -q 'Failed to load' "$tmp/qs.log" && fail "the harness did not load"
        sleep 0.1
    done
    grep -q 'Configuration Loaded' "$tmp/qs.log" || fail "the harness did not load"
    sleep 0.5
}
signal() { printf '/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (%s,)\n' "$1" >&9; }

# ---- L, started first: its stale clock runs while the main shell's steps do ----------
# Its own fake bin and FIFO: step 7 checks no main-shell gdbus outlives the
# main shell, and step 6 kills the main shell's monitor by its FIFO.
bash "$root/tests/fake-logind.sh" "$tmp/lockbin"
lockfifo="$tmp/lock.fifo"
mkfifo "$lockfifo"
mkdir -p "$tmp/lockhome"
# Each lock its own runtime dir, so the main shell's mark (in $rt) is not
# theirs: the mark checks write their own.
lock_env=(env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SHELL_SANDBOX -u SBX_RUNTIME -u SHELL_DRY_RUN
    HOME="$tmp/lockhome" PATH="$tmp/lockbin:$PATH" XDG_STATE_HOME="$tmp/lockstate" XDG_CACHE_HOME="$tmp/lockcache"
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic)
for d in lockrt markrt oldrt; do mkdir -p "$tmp/$d" && chmod 700 "$tmp/$d"; done
# lock_wait EXPR [LIMIT [PID RT]]: poll a lock's inspect (the L lock's by
# default) until a python expression on s (its `sleep` block) holds.
lock_wait() {
    local expr=$1 limit=${2:-40} pid=${3:-$lockpid} lrt=${4:-$tmp/lockrt} out=""
    for _ in $(seq 1 "$limit"); do
        out=$("${lock_env[@]}" XDG_RUNTIME_DIR="$lrt" qs ipc --pid "$pid" call lock inspect 2>/dev/null || true)
        if [ -n "$out" ] && python3 -c "import json,sys; s=json.loads(sys.argv[1])['sleep']; sys.exit(0 if ($expr) else 1)" "$out"; then
            python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])["sleep"]))' "$out"
            return 0
        fi
        sleep 0.1
    done
    fail "lock: timed out waiting for $expr: $out"
}
lock_t0=$(date +%s%N)
"${lock_env[@]}" XDG_RUNTIME_DIR="$tmp/lockrt" FAKE_PREPARING=true FAKE_LOGIND_FIFO="$lockfifo" qs -n -p "$cfg/lock.qml" --no-color >"$tmp/lock.log" 2>&1 &
lockpid=$!
exec 8<>"$lockfifo"
# A fresh mark and a watch that never reads (its `gdbus call` hangs).
printf '%s\n' "$(( $(date +%s%N) / 1000000 - 200 ))" >"$tmp/markrt/quickshell-sleep-fade"
"${lock_env[@]}" XDG_RUNTIME_DIR="$tmp/markrt" FAKE_READ_HANG=1 qs -n -p "$cfg/lock.qml" --no-color >"$tmp/mark.log" 2>&1 &
markpid=$!

# ---- 2 ---------------------------------------------------------------------------
mark() { tr -d '\n' <"$rt/quickshell-sleep-fade"; }
start
v=$(wait_for 'v["inhibitor"] and v["monitor"] and v["state"] == "open"')
echo "awake: $v"
[ "$(mark)" = 0 ] || fail "awake, the mark is 0: $(mark)"
[ "$(field "$v" mapped)" = false ] || fail "awake, the overlay is unmapped"
[ "$(field "$v" listening)" = true ] || fail "the listener runs outside the sandbox"
grep -q -- '--what=sleep --mode=delay --who=Quickshell' "$tmp/inhibit.log" || fail "a sleep delay inhibitor: $(cat "$tmp/inhibit.log")"
[ "$(grep -c '^inhibit ' "$tmp/inhibit.log")" = 1 ] || fail "one inhibitor"
ps -o args= -p "$(grep '^inhibit ' "$tmp/inhibit.log" | tail -1 | cut -d' ' -f2)" | grep -q systemd-inhibit || fail "the inhibitor runs"

# ---- 3 ---------------------------------------------------------------------------
t0=$(date +%s%N)
signal true
v=$(wait_for 'v["state"] == "closing"' 20)
echo "closing: $v"
[ "$(field "$v" blocking)" = true ] && [ "$(field "$v" mapped)" = true ] || fail "closing: mapped and taking the pointer"
[ "$(field "$v" inhibitor)" = true ] || fail "held while it fades"
age=$(( $(date +%s%N) / 1000000 - $(mark) ))
[ "$age" -ge 0 ] && [ "$age" -lt 2000 ] || fail "closing: the mark is the time it began: $(mark), ${age} ms ago"
v=$(wait_for 'v["state"] == "closed" and not v["inhibitor"]' 40)
t1=$(date +%s%N)
echo "closed: $v"
after=$(field "$v" releasedAfter)
[ "$after" -ge 350 ] && [ "$after" -le 1000 ] || fail "released after the fade, within the 1 s cap: $after ms"
echo "released ${after} ms after PrepareForSleep (wall $(( (t1 - t0) / 1000000 )) ms incl. IPC polling)"
grep -qE '^(released|term) ' "$tmp/inhibit.log" || fail "the inhibitor's process ended: $(cat "$tmp/inhibit.log")"
[ "$(field "$v" level)" = 1 ] || fail "black"

# ---- 4 ---------------------------------------------------------------------------
signal false
v=$(wait_for 'v["state"] == "opening"' 20)
echo "opening: $v"
[ "$(field "$v" blocking)" = false ] && [ "$(field "$v" mapped)" = true ] || fail "opening: mapped, the pointer through"
[ "$(mark)" = 0 ] || fail "opening: the mark is 0 again: $(mark)"
v=$(wait_for 'v["inhibitor"]' 20)
[ "$(grep -c '^inhibit ' "$tmp/inhibit.log")" = 2 ] || fail "taken again on wake: $(cat "$tmp/inhibit.log")"
v=$(wait_for 'v["state"] == "open"' 40)
[ "$(field "$v" mapped)" = false ] || fail "open: unmapped"
echo "open again: $v"

# ---- L: the lock started during a sleep ------------------------------------------------
# Past its 1 s arrive timer by now: the reading settled the watch, and the
# lock-in motion waits for the wake.
s=$(lock_wait 's["preparing"] and s["settled"] and s["monitor"] and s["held"] and not s["due"] and not s["shown"]' 60)
echo "lock started asleep: $s"
s=$(lock_wait 's["marked"] and s["asleep"] and not s["settled"] and not s["preparing"] and s["held"] and not s["shown"]' 60 "$markpid" "$tmp/markrt")
echo "lock started on a fresh mark, no reading: $s"
# An old mark (a minute old: a dead shell's) counts for nothing.
printf '%s\n' "$(( $(date +%s%N) / 1000000 - 60000 ))" >"$tmp/oldrt/quickshell-sleep-fade"
"${lock_env[@]}" XDG_RUNTIME_DIR="$tmp/oldrt" FAKE_READ_HANG=1 qs -n -p "$cfg/lock.qml" --no-color >"$tmp/old.log" 2>&1 &
oldpid=$!
s=$(lock_wait 'not s["marked"] and not s["asleep"] and not s["settled"] and s["shown"]' 60 "$oldpid" "$tmp/oldrt")
echo "lock started on an old mark: $s"
kill "$oldpid"
wait "$oldpid" 2>/dev/null || true

# ---- 5 ---------------------------------------------------------------------------
: >"$tmp/stale-start"
signal true
v=$(wait_for 'v["state"] == "closed" and not v["inhibitor"]' 40)
v=$(wait_for 'v["state"] in ("opening", "open") and v["stales"] == 1' 60)
echo "missed wake, stale: $v"
v=$(wait_for 'v["state"] == "open" and v["inhibitor"] and not v["preparing"]' 40)
grep -q 'no wake signal 1500 ms after PrepareForSleep; opening' "$tmp/qs.log" || fail "the stale is logged"
starts=$(field "$v" inhibitorStarts)
t0=$(date +%s%N)
signal true
v=$(wait_for 'v["state"] in ("closing", "closed")' 20)
echo "the next sleep counts: $v"
v=$(wait_for 'v["state"] == "closed" and not v["inhibitor"]' 40)
took=$(( ($(date +%s%N) - t0) / 1000000 ))
after=$(field "$v" releasedAfter)
[ "$after" -ge 350 ] && [ "$after" -le 1000 ] || fail "after a stale sleep, released within the 1 s cap: $after ms"
echo "after the stale: released ${after} ms after the next PrepareForSleep (wall ${took} ms incl. polling)"
[ "$(field "$v" inhibitorStarts)" = "$starts" ] || fail "no new inhibitor while it fades"
signal false
v=$(wait_for 'v["state"] == "open" and v["inhibitor"]' 60)

# ---- 6 ---------------------------------------------------------------------------
signal true
wait_for 'v["state"] in ("closing", "closed")' 20 >/dev/null
pkill -f "cat $fifo" || fail "no fake monitor to kill"
v=$(wait_for 'v["state"] in ("opening", "open")' 40)
echo "monitor lost: $v"
[ "$(field "$v" inhibitor)" = false ] || fail "no listener, no inhibitor: logind must not wait out InhibitDelayMaxSec on a lock nobody releases"
wait_for 'v["monitor"]' 100 >/dev/null || fail "the monitor comes back"
exec 9>&-
exec 9<>"$fifo"
wait_for 'v["state"] == "open" and v["inhibitor"]' 60 >/dev/null

# ---- L: the lock's stale and the next sleep ----------------------------------------
s=$(lock_wait 'not s["preparing"] and s["stales"] == 1' 140)
stale_ms=$(( ($(date +%s%N) - lock_t0) / 1000000 ))
echo "lock: stale after ${stale_ms} ms from its start: $s"
[ "$stale_ms" -ge 9500 ] || fail "the lock's watch went stale after only ${stale_ms} ms (10 s of awake time)"
s=$(lock_wait 's["shown"] and not s["held"]' 20)
echo "lock: back up: $s"
printf '/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)\n' >&8
s=$(lock_wait 's["preparing"] and s["shown"]' 20)
echo "lock: the next sleep counts: $s"
printf '/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)\n' >&8
lock_wait 'not s["preparing"] and s["stales"] == 1' 20 >/dev/null
kill "$lockpid"
wait "$lockpid" 2>/dev/null || true
lockpid=""
exec 8>&-
# The fresh mark, 10 s on, with still no reading: let go, the content in.
s=$(lock_wait 'not s["marked"] and not s["asleep"] and not s["settled"] and s["shown"] and not s["held"]' 60 "$markpid" "$tmp/markrt")
echo "lock on the mark, 10 s on with no reading: $s"
kill "$markpid"
wait "$markpid" 2>/dev/null || true
markpid=""
for f in lock mark old; do
    if grep -E 'ReferenceError|TypeError|Binding loop|Failed to load|Cannot assign|Unable to assign' "$tmp/$f.log"; then fail "lock ($f): errors in the log"; fi
done

# ---- 7 ---------------------------------------------------------------------------
holder=$(grep '^inhibit ' "$tmp/inhibit.log" | tail -1 | cut -d' ' -f2)
kill -0 "$holder" || fail "the inhibitor is up before the kill"
kill -9 "$qspid"
wait "$qspid" 2>/dev/null || true
qspid=""
for _ in $(seq 1 40); do kill -0 "$holder" 2>/dev/null || break; sleep 0.05; done
if kill -0 "$holder" 2>/dev/null; then fail "the inhibitor outlived kill -9 of the shell"; fi
grep -qE "^(released|term) $holder\$" "$tmp/inhibit.log" || fail "the holder ended: $(cat "$tmp/inhibit.log")"
echo "kill -9: holder $holder gone ($(grep -E "^(released|term) $holder\$" "$tmp/inhibit.log"))"
pgrep -f "$tmp/bin/gdbus" >/dev/null && fail "the monitor outlived the shell"
exec 9>&-

# ---- 8 ---------------------------------------------------------------------------
: >"$tmp/inhibit.log"
run_env+=(SHELL_SANDBOX=1)
"${run_env[@]}" qs -p "$cfg" --no-color >"$tmp/qs.log" 2>&1 &
qspid=$!
for _ in $(seq 1 100); do grep -q 'Configuration Loaded' "$tmp/qs.log" && break; sleep 0.1; done
v=$(wait_for 'v["sandbox"] and v["inhibitor"]')
[ "$(field "$v" listening)" = false ] || fail "the sandbox has no system bus: no listener"
[ ! -s "$tmp/inhibit.log" ] || fail "the sandbox never runs systemd-inhibit"
[ "$(ipc prepare true)" = "ok closing" ] || fail "sleep prepare true"
wait_for 'v["state"] == "closed"' 40 >/dev/null
[ "$(ipc hold 0.5)" = ok ] || fail "sleep hold"
v=$(wait_for 'v["level"] == 0.5' 10)
ipc hold -1 >/dev/null
[ "$(ipc prepare false)" = "ok opening" ] || fail "sleep prepare false"
wait_for 'v["state"] == "open"' 40 >/dev/null
kill "$qspid"
wait "$qspid" 2>/dev/null || true
qspid=""
if grep -E 'ReferenceError|TypeError|Binding loop|Failed to load|Cannot assign|Unable to assign' "$tmp/qs.log"; then fail "errors in the log"; fi
echo SLEEP_FADE_SH_PASS
