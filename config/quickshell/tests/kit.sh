#!/usr/bin/env bash
# Motion, lib/Spring.js and the Kit leaf components under qmltestrunner, plus
# the icon provenance check and the Kit import rules.
#
# qmltestrunner cannot load Quickshell, so this builds a stand-in `qs` module:
# the real Motion.qml, lib/Spring.js and Kit/, with stub Tokens (hackerman's
# values) and Prefs (the two motion keys). Every Tokens property Kit reads is
# stubbed. `--offline-ok` lets the provenance check pass with a SKIP line
# when the pinned Lucide package is neither cached nor downloadable.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

# Kit leaf components never import Quickshell, and no new file brings back the avatar.
if grep -nE '^\s*import\s+Quickshell' "$root"/Kit/*.qml; then
    echo "KIT_TEST_FAIL: Kit components must not import Quickshell" >&2
    exit 1
fi
if grep -nE 'NickAvatar|assets/nick' "$root"/Kit/* "$root/Motion.qml" "$root/lib/Spring.js" "$root/tests/gallery/shell.qml"; then
    echo "KIT_TEST_FAIL: NickAvatar is retired" >&2
    exit 1
fi
if grep -rn 'SpringAnimation' "$root"/Kit "$root/Motion.qml" "$root/lib/Spring.js" "$root/tests/gallery" | grep -v '^\S*:\s*//'; then
    echo "KIT_TEST_FAIL: no SpringAnimation (lib/Spring.js says why)" >&2
    exit 1
fi

qs="$tmp/qs"
mkdir -p "$qs/lib" "$qs/Kit" "$qs/tests"
cp "$root/Motion.qml" "$qs/"
cp "$root/lib/Spring.js" "$qs/lib/"
cp "$root"/Kit/*.qml "$root"/Kit/*.js "$qs/Kit/"
cp "$root/tests/tst_spring.qml" "$root/tests/tst_kit.qml" "$qs/tests/"

cat > "$qs/qmldir" <<'EOF'
module qs
singleton Tokens 1.0 Tokens.qml
singleton Motion 1.0 Motion.qml
singleton Prefs 1.0 Prefs.qml
EOF
{
    echo "module qs.Kit"
    for f in "$qs"/Kit/*.qml; do
        n=$(basename "$f" .qml)
        echo "$n 1.0 $n.qml"
    done
} > "$qs/Kit/qmldir"

cat > "$qs/Prefs.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property string motion: "spring"
    property bool reducedMotion: false
}
QML
# hackerman, main-tokens.md 1.4
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
    // Qt drops an initializer on a property named on<Capital> (it reads as a
    // signal handler), so Tokens.qml binds these two after creation; so does this.
    property color onAccent
    property color onFg
    Component.onCompleted: {
        onAccent = "#0b0c16";
        onFg = "#0b0c16";
    }
    property color bad: "#ff6b6b"
    property color darker: "#06060c"
    readonly property color scrim: Qt.rgba(11 / 255, 12 / 255, 22 / 255, 0.56)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
}
QML

runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 60 "$runner" -import "$tmp" -input "$qs/tests" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result"
# `! grep` would not stop the script here (set -e ignores a negated command).
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Icon: no icon named|Received signal' "$tmp/result"; then
    echo "KIT_TEST_FAIL: qmltestrunner logged errors" >&2
    exit 1
fi

python3 -B "$root/tests/icon-provenance.py" "$@"
printf 'KIT_TEST_PASS\n'
