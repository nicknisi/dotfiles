#!/usr/bin/env bash
# The classic modes' notification cards (Hosts/NotifStack.qml) on a fake
# server, offscreen: tests/notif-host.qml. No D-Bus server is registered and
# no notification reaches the desktop.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/*.qml "$root"/*.js "$tmp/"
cp -R "$root/lib" "$root/Kit" "$root/Island" "$root/Hosts" "$root/Panels" "$root/Lock" "$root/launcher" "$root/Commons" "$root/Ui" "$tmp/"
cp "$root/tests/notif-host.qml" "$tmp/shell.qml"
mkdir -p "$tmp/state"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen SHELL_CREW=off SHELL_DRY_RUN=1 XDG_STATE_HOME="$tmp/state" \
    timeout 30 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q NOTIF_HOST_TEST_PASS "$tmp/result"
! grep -E 'NOTIF_HOST_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|is not a type|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
