import QtQuick
import qs
import qs.Kit

// LockButton.qml - the lock screen's icon buttons (PLAN M8, Lock board):
// media prev / play / next, Suspend and Power on the pills, Unlock in the
// field. A circle by default; `radius` overrides it (Unlock is 32 x 32,
// radius 10).
//
// Enter, Return or Space press it when it has focus. A click never takes
// focus, so the focus ring answers the keyboard only (Kit/FocusRing).
//
// QtQuick only (qmltestrunner loads it).
Rectangle {
    id: button

    property int size: 36
    property string iconName: ""
    property real iconSize: 16
    property color ink: Tokens.fg
    property color fill: "transparent"
    property string label: ""

    signal activated

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: button.fill.a > 0 ? button.fill : area.containsMouse ? Tokens.fillLow : "transparent"
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: enabled

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.focusable: true
    Accessible.onPressAction: button.activated()

    Keys.onPressed: event => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            button.activated();
            event.accepted = true;
        }
    }

    // Hover over a filled button: the ink washes over the fill.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: button.ink
        visible: button.fill.a > 0
        opacity: area.pressed ? 0.12 : area.containsMouse ? 0.07 : 0
    }

    Icon {
        anchors.centerIn: parent
        name: button.iconName
        size: button.iconSize
        color: button.ink
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }

    FocusRing {}
}
