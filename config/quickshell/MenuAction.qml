import QtQuick
import QtQuick.Controls

AbstractButton {
    id: action

    readonly property bool containsMouse: action.hovered || action.visualFocus
    property int cursorShape: Qt.ArrowCursor

    signal entered()
    signal exited()

    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true
    hoverEnabled: true
    autoRepeat: false
    padding: 0
    Accessible.role: Accessible.Button

    background: Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Theme.controlRadius
    }
    Rectangle {
        parent: action
        anchors.fill: parent
        z: 100
        visible: action.visualFocus
        color: "transparent"
        radius: Theme.controlRadius
        border.width: 2
        border.color: Theme.accent
    }
    onContainsMouseChanged: containsMouse ? entered() : exited()

    Keys.onReturnPressed: event => {
        event.accepted = true;
        if (!event.isAutoRepeat) action.clicked();
    }
    Keys.onEnterPressed: event => {
        event.accepted = true;
        if (!event.isAutoRepeat) action.clicked();
    }

    HoverHandler {
        cursorShape: action.enabled ? action.cursorShape : Qt.ArrowCursor
    }
}
