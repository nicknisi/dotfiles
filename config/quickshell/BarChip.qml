// BarChip.qml - one module of the classic bar (pill, full, rail) in the
// island's material (PLAN M4, island-modes 12.2 and 12.4).
//
// BarModule.qml's API (highlighted, cornerRadius, stacked, the `scrolled`
// signal, a GridLayout content) on Tokens: transparent at rest, `fillLow`
// under the pointer, `accentTint` while its panel is open, plus a 1 px
// `accent` inset ring when `ringed` (the pill; full and rail have no ring).
// The keyboard focus ring is the Kit one. BarModule.qml stays as it is for
// the old menus (tests/menu-keys.sh).
//
// QtQuick only: no Quickshell import, so tests/bar-drag.sh loads it under
// qmltestrunner.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.Kit

AbstractButton {
    id: chip

    property bool highlighted: false
    property bool ringed: false
    property real cornerRadius: 10
    property bool stacked: false
    default property alias content: inner.data
    signal scrolled(real delta)

    implicitWidth: Math.max(32, inner.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(28, inner.implicitHeight)
    padding: 8
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    Accessible.name: text
    opacity: enabled ? 1 : 0.35
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) chip.clicked(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) chip.clicked(); }

    background: Rectangle {
        radius: chip.cornerRadius
        color: chip.highlighted ? Tokens.accentTint : chip.hovered ? Tokens.fillLow : "transparent"
        border.width: chip.highlighted && chip.ringed ? 1 : 0
        border.color: Tokens.accent
        Behavior on color {
            ColorAnimation {
                duration: Motion.effects
            }
        }
        FocusRing {
            target: parent
            show: chip.visualFocus
        }
    }

    contentItem: GridLayout {
        id: inner
        flow: chip.stacked ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4
        columnSpacing: 5
        WheelHandler {
            onWheel: event => chip.scrolled(event.angleDelta.y)
        }
    }
}
