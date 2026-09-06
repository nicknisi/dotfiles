#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root"/*.qml; do
    "$formatter" "$file" >/dev/null
done
cp "$root"/*.qml "$tmp/"
cp "$root/tests/check.qml" "$tmp/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 10 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q CAPSULE_TEST_PASS "$tmp/result"
! grep -Eq 'CAPSULE_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result"
