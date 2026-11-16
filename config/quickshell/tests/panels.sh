#!/usr/bin/env bash
# The control center's leaf components (PLAN M6) under qmltestrunner:
# tst_cc_layout (552 of 560, the tile label reaching the chevron, the parts' sizes),
# tst_sheet_nav (the sheet stack, its keys and the frame), tst_power_keys
# (the power menu's letters, arrows, Enter and Esc) and tst_cc_live (drags,
# keys and focus while the model changes under them, the arrow keys), plus
# lib/CcData.js in node (tests/cc-data.cjs).
#
# qmltestrunner cannot load Quickshell, so this builds a stand-in `qs` module
# as kit.sh does (the real Motion, Kit and leaves, stub Tokens and Prefs) and
# checks the leaves stay free of Quickshell.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

node "$root/tests/cc-data.cjs"

leaves=("$root"/Panels/{ControlCenter,QuickTile,CcMedia,LevelsCard,MiniTile,NotifCard}.qml "$root/Panels/Sheets/SheetFrame.qml" "$root/Island/PowerLayer.qml")
if grep -nE '^\s*import\s+Quickshell' "${leaves[@]}"; then
    echo "PANELS_TEST_FAIL: leaf panels must not import Quickshell" >&2
    exit 1
fi
# The retired avatar is tests/retired.sh's (the whole tree).
if grep -nE 'SpringAnimation' "$root"/Panels/*.qml "$root"/Panels/Sheets/*.qml "$root"/lib/CcData.js; then
    echo "PANELS_TEST_FAIL: no SpringAnimation" >&2
    exit 1
fi

qs="$tmp/qs"
mkdir -p "$qs/lib" "$qs/Kit" "$qs/Panels/Sheets" "$qs/Island" "$qs/tests"
cp "$root/Motion.qml" "$qs/"
cp "$root/lib/Spring.js" "$root/lib/CcData.js" "$qs/lib/"
cp "$root"/Kit/*.qml "$root"/Kit/*.js "$qs/Kit/"
cp "$root"/Panels/{ControlCenter,QuickTile,CcMedia,LevelsCard,MiniTile,NotifCard}.qml "$qs/Panels/"
cp "$root/Panels/Sheets/SheetFrame.qml" "$qs/Panels/Sheets/"
cp "$root/Island/PowerLayer.qml" "$qs/Island/"
cp "$root/tests/tst_cc_layout.qml" "$root/tests/tst_sheet_nav.qml" "$root/tests/tst_power_keys.qml" "$root/tests/tst_cc_live.qml" \
    "$root/tests/SheetStub.qml" "$qs/tests/"
# A 4 x 4 red PNG: the media card's cover (tst_cc_layout, M10).
python3 -c 'import base64,sys; sys.stdout.buffer.write(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP4z8AARwzEcQCukw/x0F8jngAAAABJRU5ErkJggg=="))' > "$qs/tests/cover.png"

cat > "$qs/qmldir" <<'EOF'
module qs
singleton Tokens 1.0 Tokens.qml
singleton Motion 1.0 Motion.qml
singleton Prefs 1.0 Prefs.qml
EOF
for dir in Kit Panels Panels/Sheets Island; do
    {
        echo "module qs.${dir//\//.}"
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
# hackerman, main-tokens.md 1.4 (kit.sh's stub).
cat > "$qs/Tokens.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
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
    // Bound after creation: Qt drops an initializer on an on<Capital> name.
    property color onAccent
    property color onFg
    Component.onCompleted: {
        onAccent = "#0b0c16";
        onFg = "#0b0c16";
    }
    property color bad: "#ff6b6b"
    property color darker: "#06060c"
    readonly property color night: "#000000"
    readonly property color scrim: Qt.rgba(11 / 255, 12 / 255, 22 / 255, 0.56)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
}
QML

runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 60 "$runner" -import "$tmp" -input "$qs/tests" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result"
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Icon: no icon named|Received signal|insufficiently annotated' "$tmp/result"; then
    echo "PANELS_TEST_FAIL: qmltestrunner logged errors" >&2
    exit 1
fi
printf 'PANELS_TEST_PASS\n'
