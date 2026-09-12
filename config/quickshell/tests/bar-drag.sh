#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{BarModule.qml,BarGeometry.js} "$tmp/"
cp "$root/tests/tst_bar_drag.qml" "$tmp/"
# Exercise the production handler and release/click guards, without starting
# desktop services inside qmltestrunner. Screen/window geometry is supplied below.
python3 - "$root" "$tmp" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:])
source = (root / 'Bar.qml').read_text()
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
(tmp / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Prefs 1.0 Prefs.qml\nsingleton NotificationState 1.0 NotificationState.qml\n')
(tmp / 'Theme.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    readonly property color fg: "white"
    readonly property color surface: "black"
    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a) }
    readonly property color raised: "#242b2c"
    readonly property color glowFill: "#33302c"
    readonly property color accent: "#e9b291"
    readonly property int controlRadius: 12
    readonly property int barHeight: 48
    readonly property int barInset: Prefs.barMode === "full" ? 0 : 18
    readonly property int quick: 0
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
QtObject { function closeCenter() {} }
''')
PY
runner=$(command -v qmltestrunner || printf /usr/lib/qt6/bin/qmltestrunner)
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 90 "$runner" -input "$tmp" "$@" 2>&1 | tee "$tmp/result"
! grep -E 'ReferenceError|TypeError|Binding loop|Cannot assign|is not a type' "$tmp/result"
