#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

node "$root/tests/launcher-model.cjs"

formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root"/*.qml; do
    "$formatter" "$file" >/dev/null
done
# Singletons may import a sibling .js, so those ride along with the .qml.
cp "$root"/*.qml "$tmp/"
cp "$root"/*.js "$tmp/" 2>/dev/null || true
cp "$root/tests/check.qml" "$tmp/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 10 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q CAPSULE_TEST_PASS "$tmp/result"
! grep -Eq 'CAPSULE_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result"
