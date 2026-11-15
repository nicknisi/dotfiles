#!/usr/bin/env bash
# Prefs' island keys (defaults, validation, persistence, junk in the file) and
# the Fixture singleton (load, errors, inert outside SHELL_SANDBOX=1), each in
# an offscreen qs with its own XDG_STATE_HOME so no real state is read or written.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/cfg/tests/fixtures" "$tmp/state"
cp "$root"/{Prefs,Fixture}.qml "$tmp/cfg/"
cp "$root/tests/services.qml" "$tmp/cfg/shell.qml"
fx=$tmp/cfg/tests/fixtures
printf '{"value": 1}\n' >"$fx/alpha.json"
printf '{"value": 2}\n' >"$fx/beta.json"
printf '{"value": \n' >"$fx/broken.json"
printf '[1, 2]\n' >"$fx/list.json"

run() {
    local phase=$1
    shift
    env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SHELL_SANDBOX \
        QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic XDG_STATE_HOME="$tmp/state" \
        SERVICES_TEST_PHASE="$phase" "$@" timeout 10 qs -p "$tmp/cfg" --no-color >"$tmp/$phase.log" 2>&1 || true
    cat "$tmp/$phase.log"
    grep -q "SERVICES_TEST_PASS $phase" "$tmp/$phase.log"
    # Prefs' first-run capsule.json miss is expected; nothing else may warn.
    ! grep -E 'SERVICES_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/$phase.log" \
        | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
}

run first
store=$(find "$tmp/state" -name capsule.json -print -quit)
[ -n "$store" ] || { echo "SERVICES_TEST_FAIL: Prefs wrote no capsule.json" >&2; exit 1; }
python3 -I - "$store" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
want = {"islandForm": "notch", "look": "arcade", "motion": "off", "reducedMotion": True, "dnd": True, "barMode": "pill"}
bad = {k: d.get(k) for k, v in want.items() if d.get(k) != v}
if bad:
    sys.exit(f"SERVICES_TEST_FAIL: capsule.json has {bad}")
d.update(islandForm="bubble", look="vaporwave", motion="warp")
json.dump(d, open(path, "w"))
PY
run stale
run fixture SHELL_SANDBOX=1
run inert
echo SERVICES_SH_PASS
