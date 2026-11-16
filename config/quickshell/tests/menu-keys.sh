#!/usr/bin/env bash
# MenuNavigation (the arrow and Ctrl+J/K walk the classic bars' Appearance
# page uses on the anchored host's page frame) inside BarMenu, under
# qmltestrunner with a stub Tokens. The old menus and their controls went in
# M10; this keeps the navigation itself covered with plain Qt controls.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{BarMenu,MenuNavigation}.qml "$tmp/"
cp "$root/tests/tst_menu_keys.qml" "$tmp/"
printf 'singleton Tokens 1.0 Tokens.qml\n' > "$tmp/qmldir"
cat > "$tmp/Tokens.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    readonly property color fg: "#eeeeee"
    readonly property color inkDim: "#abb1ab"
}
QML
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 15 "$runner" -input "$tmp" 2>&1 | tee "$tmp/result"
! grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type' "$tmp/result"
