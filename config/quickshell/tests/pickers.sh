#!/usr/bin/env bash
# The theme and wallpaper pickers (PLAN M7) under qmltestrunner:
# tst_picker_nav (wrap, column moves, the filter's fallback, Tab between the
# panels, the Esc order, the preview, the pointer gate and the layout) over
# the real PickerModel, ThemesPanel, WallpapersPanel, PickerCard and
# PickerFilter; tst_face_grid (the Profile picture sheet's grid: cards,
# circles, keys, the pointer, the empty states). The hosts (the island states, the free panel) and the live
# preview through Tokens run in check.qml; `theme _rows` in
# bin/tests/theme-rows.sh.
#
# qmltestrunner cannot load Quickshell, so this builds a stand-in `qs` module
# as panels.sh does, with a plain Item for PickerThumb (the one picker file
# that needs Quickshell.Widgets), and checks the rest stay free of Quickshell.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

leaves=("$root"/Panels/{PickerModel,PickerCard,PickerFilter,ThemesPanel,WallpapersPanel,FaceGrid}.qml)
if grep -nE '^\s*import\s+Quickshell' "${leaves[@]}" "$root/lib/PickerNav.js"; then
    echo "PICKERS_TEST_FAIL: picker leaves must not import Quickshell" >&2
    exit 1
fi
# The retired avatar is tests/retired.sh's (the whole tree).
if grep -nE 'SpringAnimation' "${leaves[@]}" "$root/Panels/PickerThumb.qml" "$root/ThemePicker.qml"; then
    echo "PICKERS_TEST_FAIL: no SpringAnimation" >&2
    exit 1
fi

qs="$tmp/qs"
mkdir -p "$qs/lib" "$qs/Kit" "$qs/Panels" "$qs/tests"
cp "$root/Motion.qml" "$qs/"
cp "$root/lib/Spring.js" "$root/lib/PickerNav.js" "$qs/lib/"
cp "$root"/Kit/*.qml "$root"/Kit/*.js "$qs/Kit/"
cp "${leaves[@]}" "$qs/Panels/"
cp "$root/tests/tst_picker_nav.qml" "$root/tests/tst_face_grid.qml" "$qs/tests/"

# PickerThumb without the ClippingRectangle: the same properties.
cat > "$qs/Panels/PickerThumb.qml" <<'QML'
import QtQuick
Item {
    property string source: ""
    property size sourceSize: Qt.size(0, 0)
    property real radius: 10
    readonly property int status: Image.Null
}
QML

cat > "$qs/qmldir" <<'QMLDIR'
module qs
singleton Tokens 1.0 Tokens.qml
singleton Motion 1.0 Motion.qml
singleton Prefs 1.0 Prefs.qml
QMLDIR
for dir in Kit Panels; do
    {
        echo "module qs.$dir"
        for f in "$qs/$dir"/*.qml; do
            n=$(basename "$f" .qml)
            echo "$n 1.0 $n.qml"
        done
    } > "$qs/$dir/qmldir"
done

cat > "$qs/Prefs.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property string motion: "spring"
    property bool reducedMotion: false
}
QML
# hackerman, main-tokens.md 1.4 (panels.sh's stub).
cat > "$qs/Tokens.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property var previewPalette: null
    property color bg: "#0b0c16"
    property color fg: "#ddf7ff"
    readonly property color ink: fg
    property color accent: "#82fb9c"
    property color surface: "#13151f"
    property color raised: "#1c1f29"
    property color overlay: "#242832"
    property color hairline: "#2f353e"
    property color fillLow: "#1f232c"
    property color fillHigh: "#2d323c"
    property color inkDim: "#8d9ea6"
    property color inkMid: "#78868f"
    property color faint: "#5a646d"
    property color accentTint: "#253a33"
    property color onAccent
    Component.onCompleted: onAccent = "#0b0c16"
    property color bad: "#ff6b6b"
    property color darker: "#06060c"
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
}
QML

runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 60 "$runner" -import "$tmp" -input "$qs/tests" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result"
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Icon: no icon named|Received signal|insufficiently annotated' "$tmp/result"; then
    echo "PICKERS_TEST_FAIL: qmltestrunner logged errors" >&2
    exit 1
fi
printf 'PICKERS_TEST_PASS\n'
