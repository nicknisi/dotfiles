#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

luajit "$root/../hypr/tests/style.lua" "$root/../hypr/hyprland.lua" "$root/../../themes/"*/hyprland.lua
bash "$root/launcher/tests/check.sh"
bash "$root/tests/voxtype-osd.sh"
node "$root/tests/clipboard-model.cjs"
"$root/tests/net.sh"

formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root"/*.qml; do
    "$formatter" "$file" >/dev/null
done
# Singletons may import a sibling .js, so those ride along with the .qml.
cp "$root"/*.qml "$tmp/"
cp "$root"/*.js "$tmp/" 2>/dev/null || true
cp -R "$root/assets" "$root/launcher" "$root/Commons" "$root/Ui" "$tmp/"
cp "$root/tests/check.qml" "$tmp/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 10 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q CAPSULE_TEST_PASS "$tmp/result"
# Prefs writes capsule.json on first load, after FileView reports that it is absent.
! grep -E 'CAPSULE_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
