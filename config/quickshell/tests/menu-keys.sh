#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{BarMenu,BarModule,MenuAction,MenuSlider}.qml "$tmp/"
[[ ! -f "$root/MenuNavigation.qml" ]] || cp "$root/MenuNavigation.qml" "$tmp/"
cp "$root/tests/tst_menu_keys.qml" "$tmp/"
printf 'singleton Theme 1.0 Theme.qml\n' > "$tmp/qmldir"
cat > "$tmp/Theme.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    readonly property color fg: "#eeeeee"
    readonly property color surface: "#171c1e"
    readonly property color raised: "#242b2c"
    readonly property color secondary: "#abb1ab"
    readonly property color accent: "#e9b291"
    readonly property color glowFill: "#33302c"
    readonly property string font: "monospace"
    readonly property int fontSize: 13
    readonly property int controlRadius: 12
    readonly property int quick: 0
}
QML
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 15 "$runner" -input "$tmp" 2>&1 | tee "$tmp/result"
! grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|is not a type' "$tmp/result"
