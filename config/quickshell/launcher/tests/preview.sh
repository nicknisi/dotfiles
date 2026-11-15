#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{Theme,Prefs}.qml "$root/BarGeometry.js" "$tmp/"
cp -R "$root/Commons" "$tmp/"
cp "$root/launcher/ui/PreviewPane.qml" "$tmp/"
cp "$root/launcher/tests/preview.qml" "$tmp/shell.qml"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80"><rect width="100" height="80" fill="blue"/></svg>' > "$tmp/image.svg"
# XDG_STATE_HOME: Prefs' capsule.json stays in $tmp, not ~/.local/state.
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen XDG_STATE_HOME="$tmp/state" timeout 10 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q PREVIEW_TEST_PASS "$tmp/result"
! grep -E 'PREVIEW_TEST_FAIL|ReferenceError|TypeError|Binding loop|Failed to load|Cannot assign' "$tmp/result"
