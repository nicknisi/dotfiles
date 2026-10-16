#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{BarModule.qml,BarMedia.qml,BarGeometry.js,AudioOutput.js} "$tmp/"
cp "$root/tests/"{tst_bar_drag.qml,tst_bar_actions.qml} "$tmp/"
# Exercise the production handler and release/click guards, without starting
# desktop services inside qmltestrunner. Screen/window geometry is supplied below.
python3 - "$root" "$tmp" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:])
source = (root / 'Bar.qml').read_text()
(tmp / 'art.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="teal"/></svg>')
def block(marker):
    start = source.index(marker)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]
functions = '\n'.join(block('function ' + name + '(') for name in ['consumeClick', 'nearestEdge', 'finishDrag'])
geometry = source[source.index('    readonly property string edge:'):source.index('    property bool suppressClicks:')]
body = source[source.index('    Item {\n        id: body'):source.index('        DragHandler {')]
(tmp / 'BarDragFixture.qml').write_text('''import QtQuick
import "BarGeometry.js" as BarGeometry
Item {
    id: bar
''' + geometry + '''
    property var screen: ({width: 1920, height: 1080})
    width: vertical ? thick + 2 * inset : screen.width
    height: vertical ? screen.height : thick + 2 * inset
    property bool suppressClicks: false
    property string dragEdge: edge
    property string openMenu: ""
    property int clicks: 0
    property int scrolls: 0
    property alias button: button
    property alias surface: body
    property alias background: surface
    property alias handler: drag
    BarMedia { id: mediaButton; vertical: bar.vertical; showDetails: !vertical && bar.along >= 800; visible: false }
    function registerBell() {}
    Timer { id: clickReset; interval: 160; onTriggered: bar.suppressClicks = false }
''' + functions + body + block('DragHandler {') + block('Rectangle {\n            id: surface') + '''
        BarModule {
            id: button
            width: 32; height: 32; x: 8; y: 8
            text: "Test button"
            onClicked: if (!bar.consumeClick()) bar.clicks++
            onScrolled: delta => { if (delta !== 0) bar.scrolls++ }
        }
    }
}
''')
# Extract the real buttons as well: mouse tests exercise their actual handlers,
# with desktop services replaced by counters rather than controlling real apps.
buttons = block('BarMedia {\n                    id: mediaButton') + '\n' + '\n'.join(
    block('StatusButton {\n                    id: ' + name)
    for name in ['notificationsButton', 'audioButton'])
(tmp / 'BarActionsFixture.qml').write_text('''import QtQuick
import QtQuick.Layouts
Item {
    id: bar
    width: 400; height: 180
    readonly property real along: 1000
    property bool vertical: false
    property bool suppressClicks: false
    property string openMenu: ""
    property var screen: null
    property var menuAnchor: null
    property alias media: mediaButton
    property alias bell: notificationsButton
    property alias audio: audioButton
    function registerBell() {}
    function consumeClick() {
        if (!suppressClicks) return false;
        suppressClicks = false;
        return true;
    }
    function toggleMenu(name, item) {
        if (!consumeClick()) { openMenu = name; menuAnchor = item; }
    }
    RowLayout { y: 10
''' + buttons + '\n}\n' + block('component StatusButton: BarModule {') + '\n}\n')
(tmp / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Prefs 1.0 Prefs.qml\nsingleton NotificationState 1.0 NotificationState.qml\nsingleton Media 1.0 Media.qml\nsingleton Audio 1.0 Audio.qml\n')
(tmp / 'Media.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property var player: null }
''')
(tmp / 'Audio.qml').write_text('''pragma Singleton
import QtQuick
import "AudioOutput.js" as AudioOutput
QtObject {
    property var sink: null
    property bool muted: false
    property bool ready: true
    property real volume: 0.5
    readonly property string outputIcon: AudioOutput.icon(sink, muted)
    function labelFor(node) { return node?.nickname || "unknown" }
    function setVolume(node, value) { volume = value }
}
''')
(tmp / 'Theme.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property color fg: "white"
    readonly property color surface: "black"
    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a) }
    readonly property color raised: "#242b2c"
    readonly property color glowFill: "#33302c"
    readonly property color accent: "#e9b291"
    readonly property color secondary: "#aaaaaa"
    readonly property color red: "#ff0000"
    readonly property color yellow: "#ffff00"
    readonly property string icons: "sans-serif"
    readonly property string font: "sans-serif"
    readonly property int controlRadius: 12
    readonly property int barHeight: 40
    readonly property int barInset: Prefs.barMode === "full" ? 0 : 8
    readonly property int quick: 0
    readonly property int unfold: 220
}
''')
(tmp / 'Prefs.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property string edge: "top"
    property string barMode: "pill"
    property bool translucent: false
    function toggleTranslucent() { translucent = !translucent }
    readonly property bool vertical: edge === "left" || edge === "right"
    function setEdge(value) { edge = value }
}
''')
(tmp / 'NotificationState.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool centerOpen: false
    property var centerScreen: null
    property bool dnd: false
    property int unread: 0
    property int count: 0
    function toggleDnd() { dnd = !dnd }
    function toggleCenter(screen) { centerOpen = !centerOpen; centerScreen = screen }
    function closeCenter() { centerOpen = false }
}
''')
PY
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 90 "$runner" -input "$tmp" "$@" 2>&1 | tee "$tmp/result"
! grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|is not a type' "$tmp/result"
