#!/usr/bin/env bash
# Backlight.qml (final audit): the level from a fake sysfs dir through
# FileView polling, a change picked up within a poll, one `changed` per real
# change, nothing read without a backlight, and no child process at all (the
# old `sh` loop forked `sleep` and `cat` about 7 times a second).
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/cfg" "$tmp/sys" "$tmp/none" "$tmp/state"
sed "s|\"/sys/class/backlight/intel_backlight\"|\"$tmp/sys\"|" "$root/Backlight.qml" >"$tmp/cfg/Backlight.qml"
grep -q "\"$tmp/sys\"" "$tmp/cfg/Backlight.qml" || { echo "BACKLIGHT_TEST_FAIL: the dir line moved" >&2; exit 1; }
cp "$root/tests/backlight.qml" "$tmp/cfg/shell.qml"
printf '200\n' >"$tmp/sys/max_brightness"
printf '50\n' >"$tmp/sys/brightness"

run() {
    local phase=$1 dir=$2
    env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic XDG_STATE_HOME="$tmp/state" \
        BACKLIGHT_TEST_PHASE="$phase" BACKLIGHT_TEST_DIR="$dir" timeout 10 qs -p "$tmp/cfg" --no-color >"$tmp/$phase.log" 2>&1 &
    local pid=$! kids=0
    # sleep or cat under qs (children and grandchildren) while it polls; the
    # test's own writer is one short `sh` with neither.
    for _ in 1 2 3 4 5 6; do
        sleep 0.2
        local q
        q=$(pgrep -P "$pid" -x qs || true)
        [ -n "$q" ] || q=$pid
        for c in $(pgrep -P "$q" || true); do
            for g in "$c" $(pgrep -P "$c" || true); do
                case $(cat "/proc/$g/comm" 2>/dev/null) in sleep | cat) kids=$((kids + 1)) ;; esac
            done
        done
    done
    wait "$pid" || true
    cat "$tmp/$phase.log"
    grep -q "BACKLIGHT_TEST_PASS $phase" "$tmp/$phase.log"
    ! grep -E 'BACKLIGHT_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop' "$tmp/$phase.log"
    [ "$kids" = 0 ] || { echo "BACKLIGHT_TEST_FAIL: $kids sleep or cat children while polling" >&2; exit 1; }
}

run live "$tmp/sys"
sed -i "s|\"$tmp/sys\"|\"$tmp/none\"|" "$tmp/cfg/Backlight.qml"
run none "$tmp/none"
echo BACKLIGHT_TEST_PASS
