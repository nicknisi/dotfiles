#!/usr/bin/env bash
# NightLight.qml against a fake hyprsunset (no real one runs here, and the
# session's must never be touched): fake hyprctl, journalctl and systemctl on
# PATH, a fake HYPRLAND_INSTANCE_SIGNATURE, and an isolated XDG_STATE_HOME,
# XDG_CONFIG_HOME (the dotfiles' hyprsunset.conf, its 07:00 identity profile)
# and XDG_RUNTIME_DIR. tests/nightlight.qml runs the phases: the schedule's
# edges across midnight on a fake clock, one call per change and none per
# tick, the manual override until the next edge, hyprsunset's 07:00 profile
# inside an active window put back on its journal line (on time, and late
# after a resume) or by the clock without a journal, schedule Off keeping the
# light as it is, a daemon stop and restart (re-applied), the state kept
# across a shell restart, unavailable at start with the explicit
# `systemctl --user start`, the dry run and no session spawning nothing. Then
# the `nightlight` IPC target through `qs ipc call` on a running instance.
# NL_KEEP=1 leaves the temp dir (the logs, the fakes' state) for a look.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    [ -n "${NL_KEEP:-}" ] || rm -rf -- "$tmp"
}
trap cleanup EXIT
cfg=$tmp/cfg
fake=$tmp/fake
mkdir -p "$cfg/lib" "$cfg/tests/fixtures" "$tmp/bin" "$tmp/state" "$tmp/config/hypr" "$tmp/rt" "$fake"
chmod 700 "$tmp/rt"
cp "$root"/{NightLight,Prefs,Fixture}.qml "$root/BarGeometry.js" "$cfg/"
cp "$root/lib/NightLight.js" "$cfg/lib/"
cp "$root/tests/nightlight.qml" "$cfg/shell.qml"
cp "$root/../hypr/hyprsunset.conf" "$tmp/config/hypr/"

# hyprsunset 0.4.0's answers (probed in the sandbox): "ok" for a setter, the
# kelvin for a bare `temperature`, and without its socket "Couldn't connect
# to <rt>/hypr/<sig>/.hyprsunset.sock. (3)" with exit 3.
cat >"$tmp/bin/hyprctl" <<'SH'
#!/bin/sh
d=$NL_FAKE
printf '%s\n' "$*" >>"$d/calls"
[ "$1" = hyprsunset ] || { echo "unexpected hyprctl $*"; exit 9; }
if [ ! -f "$d/running" ]; then
    echo "Couldn't connect to $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock. (3)"
    exit 3
fi
case "$2" in
temperature)
    if [ -z "${3:-}" ]; then cat "$d/kelvin" 2>/dev/null || echo 6000; exit 0; fi
    case $3 in *[!0-9]*) echo "Invalid temperature (should be an integer in range 1000-20000)"; exit 0 ;; esac
    echo "$3" >"$d/kelvin"
    echo "$3" >"$d/screen"
    echo ok
    ;;
identity)
    echo identity >"$d/screen"
    echo ok
    ;;
*) echo "invalid command" ;;
esac
SH
# Follows the fake journal from its end, as --follow --lines=0 does; exits at
# once while $NL_FAKE/nojournal is there.
cat >"$tmp/bin/journalctl" <<'SH'
#!/bin/sh
d=$NL_FAKE
printf '%s\n' "$*" >"$d/journalctl.args"
n=$(cat "$d/journalctl.runs" 2>/dev/null || echo 0)
echo $((n + 1)) >"$d/journalctl.runs"
[ -f "$d/nojournal" ] && exit 1
exec tail -n 0 -F "$d/journal" 2>/dev/null
SH
cat >"$tmp/bin/systemctl" <<'SH'
#!/bin/sh
d=$NL_FAKE
printf '%s\n' "$*" >"$d/systemctl.args"
echo identity >"$d/screen"
touch "$d/running"
echo "Started An application to enable a blue-light filter on Hyprland.." >>"$d/journal"
SH
chmod +x "$tmp/bin/"*

reset_fake() {
    rm -f "$fake"/*
    : >"$fake/journal"
    echo identity >"$fake/screen"
    [ "${1:-up}" = down ] || touch "$fake/running"
}

envs=(QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic PATH="$tmp/bin:$PATH" NL_FAKE="$fake"
    XDG_STATE_HOME="$tmp/state" XDG_CONFIG_HOME="$tmp/config" XDG_RUNTIME_DIR="$tmp/rt")
run() {
    local phase=$1
    shift
    env -u WAYLAND_DISPLAY -u SHELL_SANDBOX -u SHELL_DRY_RUN -u HYPRLAND_INSTANCE_SIGNATURE "${envs[@]}" NL_TEST_PHASE="$phase" "$@" \
        timeout 60 qs -p "$cfg" --no-color >"$tmp/$phase.log" 2>&1 || true
    cat "$tmp/$phase.log"
    grep -q "NIGHTLIGHT_TEST_PASS $phase" "$tmp/$phase.log"
    # Prefs' first-run capsule.json miss is expected; nothing else may warn.
    ! grep -E 'NIGHTLIGHT_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/$phase.log" \
        | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
}

sig=nightlight-test-sig
reset_fake
run first HYPRLAND_INSTANCE_SIGNATURE=$sig
run restart HYPRLAND_INSTANCE_SIGNATURE=$sig
rm -rf "$tmp/state"/*
reset_fake down
run down HYPRLAND_INSTANCE_SIGNATURE=$sig
rm -rf "$tmp/state"/*
reset_fake
touch "$fake/nojournal"
run nojournal HYPRLAND_INSTANCE_SIGNATURE=$sig
reset_fake
run dry HYPRLAND_INSTANCE_SIGNATURE=$sig SHELL_DRY_RUN=1
reset_fake
run session

# The IPC target, on a running instance (the test shell, its runner held
# back by a phase with no steps).
rm -rf "$tmp/state"/*
reset_fake
# env directly: $! must be qs itself, for --pid.
env -u WAYLAND_DISPLAY -u SHELL_SANDBOX -u SHELL_DRY_RUN "${envs[@]}" HYPRLAND_INSTANCE_SIGNATURE=$sig NL_TEST_PHASE=idle \
    qs -p "$cfg" --no-color >"$tmp/ipc.log" 2>&1 &
qpid=$!
pids+=($qpid)
ipc() { env "${envs[@]}" qs ipc --pid "$qpid" call nightlight "$@" 2>&1 || true; }
for _ in $(seq 1 50); do
    ipc inspect | grep -q '"available":true' && break
    sleep 0.2
done
fail() { echo "NIGHTLIGHT_TEST_FAIL ipc: $*" >&2; cat "$tmp/ipc.log" >&2; exit 1; }
out=$(ipc inspect)
python3 -I - "$out" <<'PY' || fail "inspect: $out"
import json, sys
d = json.loads(sys.argv[1])
want = {"on": False, "available": True, "temperature": 4000, "schedule": "off", "from": "20:00", "to": "07:00", "lastCommand": "hyprctl hyprsunset identity"}
bad = {k: d.get(k) for k, v in want.items() if d.get(k) != v}
sys.exit(f"inspect has {bad}" if bad else 0)
PY
[ "$(ipc on)" = ok ] || fail "on"
sleep 0.4
[ "$(cat "$fake/screen")" = 4000 ] || fail "on did not reach the screen: $(cat "$fake/screen")"
[ "$(ipc temperature 3600)" = "ok 3600" ] || fail "temperature 3600"
sleep 0.5
[ "$(cat "$fake/screen")" = 3600 ] || fail "temperature did not reach the screen: $(cat "$fake/screen")"
case $(ipc temperature 900) in error*) ;; *) fail "temperature 900 accepted" ;; esac
[ "$(ipc toggle)" = ok ] || fail "toggle"
sleep 0.4
[ "$(cat "$fake/screen")" = identity ] || fail "toggle off did not reach the screen"
[ "$(ipc off)" = ok ] || fail "off"
[ "$(ipc schedule 21:00-06:30)" = ok ] || fail "schedule 21:00-06:30"
case $(ipc schedule 25:00-06:30) in error*) ;; *) fail "a bad schedule accepted" ;; esac
out=$(ipc inspect)
python3 -I - "$out" <<'PY' || fail "inspect after: $out"
import json, sys
d = json.loads(sys.argv[1])
want = {"temperature": 3600, "schedule": "custom", "from": "21:00", "to": "06:30", "profiles": ["07:00 identity"], "watch": "watching"}
bad = {k: d.get(k) for k, v in want.items() if d.get(k) != v}
sys.exit(f"inspect has {bad}" if bad else 0)
PY
# Off keeps whatever the schedule shows at this real hour (on at night).
was=$(python3 -I -c 'import json, sys; print(json.loads(sys.argv[1])["on"])' "$out")
[ "$(ipc schedule off)" = ok ] || fail "schedule off"
sleep 0.4
store=$(find "$tmp/state" -name capsule.json -print -quit)
python3 -I - "$store" "$was" "$(ipc inspect)" <<'PY' || fail "capsule.json"
import json, sys
d = json.load(open(sys.argv[1]))
was = sys.argv[2] == "True"
if json.loads(sys.argv[3])["on"] != was:
    sys.exit(f"schedule off flipped the light from {was}")
want = {"nightLightTemperature": 3600, "nightLightSchedule": "off", "nightLightFrom": "21:00", "nightLightTo": "06:30", "nightLightOn": was}
bad = {k: d.get(k) for k, v in want.items() if d.get(k) != v}
sys.exit(f"capsule.json has {bad}" if bad else 0)
PY
grep -vxE 'hyprsunset (identity|temperature [0-9]+)' "$fake/calls" && fail "hyprctl ran something else"
kill "${pids[@]}" 2>/dev/null || true
echo NIGHTLIGHT_TEST_PASS
