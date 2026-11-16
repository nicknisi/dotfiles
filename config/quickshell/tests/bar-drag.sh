#!/usr/bin/env bash
# The classic bar (PLAN M4) under qmltestrunner: tst_bar_drag (layout,
# material, drags between edges, the double-tap, the seam), tst_bar_actions
# (every module's click, wheel and menu, privacy, keep awake, the tray, the
# bell and Do not disturb, recording stop) and tst_anchored_corners
# (lib/Anchored.js placement and Hosts/AnchoredFrame.qml's corners and
# hairlines for every mode, edge and module position).
#
# It runs the real BarView.qml, BarChip.qml, BarMedia.qml, BarGeometry.js,
# AudioOutput.js, lib/Anchored.js and Hosts/AnchoredFrame.qml, with the real
# Motion and Kit, in a stand-in `qs` module (qmltestrunner cannot load
# Quickshell): stub Tokens (hackerman's values), Theme and Prefs (Prefs' edge
# rules are BarGeometry.js's, the same functions the real one calls), and
# stand-ins for the services the modules read, which count what the bar asks
# of them instead of controlling real apps.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

leaves=("$root"/{BarView,BarChip,BarMedia}.qml "$root/Hosts/AnchoredFrame.qml")
if grep -nE '^\s*import\s+Quickshell' "${leaves[@]}"; then
    echo "BAR_TEST_FAIL: the bar's leaves must not import Quickshell" >&2
    exit 1
fi
# The retired avatar is tests/retired.sh's (the whole tree).
if grep -nE 'SpringAnimation' "${leaves[@]}" "$root/Bar.qml" "$root/Hosts/"*.qml "$root/lib/Anchored.js"; then
    echo "BAR_TEST_FAIL: no SpringAnimation" >&2
    exit 1
fi

qs="$tmp/qs"
mkdir -p "$qs/lib" "$qs/Kit" "$qs/Hosts" "$qs/tests"
cp "$root/Motion.qml" "$root"/{BarView,BarChip,BarMedia}.qml "$root"/{BarGeometry,AudioOutput}.js "$qs/"
cp "$root"/lib/*.js "$qs/lib/"
cp "$root"/Kit/*.qml "$root"/Kit/*.js "$qs/Kit/"
cp "$root/Hosts/AnchoredFrame.qml" "$qs/Hosts/"
cp "$root/tests/"{tst_bar_drag,tst_bar_actions,tst_anchored_corners}.qml "$qs/tests/"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="teal"/></svg>' > "$qs/tests/art.svg"

singletons=(Tokens Motion Prefs Theme NotificationState Media Audio Capture Caffeine Net Battery)
{
    echo "module qs"
    for n in "${singletons[@]}"; do echo "singleton $n 1.0 $n.qml"; done
    for n in BarView BarChip BarMedia; do echo "$n 1.0 $n.qml"; done
} > "$qs/qmldir"
for dir in Kit Hosts; do
    {
        echo "module qs.$dir"
        for f in "$qs/$dir"/*.qml; do
            n=$(basename "$f" .qml)
            echo "$n 1.0 $n.qml"
        done
    } > "$qs/$dir/qmldir"
done

# Prefs: the edge rules are BarGeometry.js's, as in Prefs.qml.
cat > "$qs/Prefs.qml" <<'QML'
pragma Singleton
import QtQuick
import "BarGeometry.js" as BarGeometry
QtObject {
    property string motion: "spring"
    property bool reducedMotion: false
    readonly property var barModes: ["pill", "full", "rail", "island"]
    property string barMode: "pill"
    property string storedEdge: "top"
    readonly property string edge: BarGeometry.edgeFor(barMode, storedEdge)
    readonly property bool vertical: edge === "left" || edge === "right"
    property bool translucent: false
    function toggleTranslucent() { translucent = !translucent }
    function setBarMode(mode) { if (barModes.indexOf(mode) >= 0) barMode = mode }
    function setEdge(edge) {
        const next = BarGeometry.moveTo(barMode, edge);
        if (!next) return;
        storedEdge = next.edge;
        if (next.mode !== barMode) barMode = next.mode;
    }
}
QML
cat > "$qs/Theme.qml" <<'QML'
pragma Singleton
import QtQuick
import "BarGeometry.js" as BarGeometry
QtObject {
    readonly property int barHeight: 40
    readonly property int barInset: BarGeometry.inset(Prefs.barMode)
    readonly property string icons: "sans-serif"
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
    readonly property color scrim: Qt.rgba(11 / 255, 12 / 255, 22 / 255, 0.56)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
}
QML
cat > "$qs/NotificationState.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool dnd: false
    property int unread: 0
    property int count: 0
    property int reads: 0
    property var focused: []
    function toggleDnd() { dnd = !dnd }
    function markRead() { unread = 0; reads++ }
    function focusApp(names) { focused = focused.concat([names]); return true }
}
QML
cat > "$qs/Media.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject { property var player: null }
QML
cat > "$qs/Audio.qml" <<'QML'
pragma Singleton
import QtQuick
import "AudioOutput.js" as AudioOutput
QtObject {
    property var sink: null
    property bool muted: false
    property bool ready: true
    property real volume: 0.5
    property var recorders: []
    readonly property string outputIcon: AudioOutput.icon(sink, muted)
    readonly property string outputIconName: AudioOutput.iconName(sink, muted)
    function labelFor(node) { return node?.nickname || "unknown" }
    function appFor(node) { return node?.app || "an app" }
    function setVolume(node, value) { volume = value }
}
QML
cat > "$qs/Capture.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool recording: false
    property int stops: 0
    function stop() { stops++ }
}
QML
cat > "$qs/Caffeine.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool active: false
    readonly property string status: active ? "1 hour" : "off"
}
QML
cat > "$qs/Net.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool connected: true
    property bool portal: false
    property var device: ({})
}
QML
cat > "$qs/Battery.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    property bool present: true
    property int percent: 64
    property bool charging: false
    readonly property bool low: percent <= 20 && !charging
}
QML

runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    timeout -k 5 150 "$runner" -import "$tmp" -input "$qs/tests" "$@" 2>&1 | tee "$tmp/result"
grep -qE '^Totals: [0-9]+ passed, 0 failed' "$tmp/result"
if grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|is not defined|Icon: no icon named|Received signal|insufficiently annotated' "$tmp/result"; then
    echo "BAR_TEST_FAIL: qmltestrunner logged errors" >&2
    exit 1
fi
printf 'BAR_TEST_PASS\n'
