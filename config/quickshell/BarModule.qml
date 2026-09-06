// Stable, keyboard-accessible capsule and HUD button. Labels are tooltips,
// never expanding layout children that move the next target under the pointer.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: mod

    property bool highlighted: false
    property real cornerRadius: height / 2
    default property alias content: inner.data
    signal scrolled(real delta)

    implicitWidth: Math.max(32, inner.implicitWidth + 16)
    implicitHeight: 32
    padding: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    opacity: enabled ? 1 : 0.35
    scale: down ? 0.88 : (hovered ? 1.07 : 1)
    Behavior on scale {
        NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
    }

    ToolTip {
        parent: mod
        visible: mod.hovered && mod.text !== ""
        text: mod.text
        delay: 650
        background: Rectangle {
            radius: 8
            color: Theme.raised
            border.width: 1
            border.color: Theme.borderIdle
        }
        contentItem: Text {
            text: mod.text
            textFormat: Text.PlainText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            color: Theme.fg
        }
    }

    background: Rectangle {
        radius: mod.cornerRadius
        color: mod.highlighted ? Theme.glowFill : (mod.hovered ? Theme.raised : "transparent")
        border.width: mod.visualFocus ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on radius { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
    }

    contentItem: RowLayout {
        id: inner
        spacing: 6
        WheelHandler {
            onWheel: event => mod.scrolled(event.angleDelta.y)
        }
    }
}
