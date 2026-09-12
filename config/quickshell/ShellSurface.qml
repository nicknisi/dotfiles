import QtQuick

Rectangle {
    property color fill: Theme.surface
    property bool prominent: false
    property color outlineColor: prominent ? Theme.alpha(Theme.fg, 0.18) : Theme.borderIdle
    property real outlineWidth: 1

    radius: Theme.panelRadius
    color: fill
    border.width: outlineWidth
    border.color: outlineColor
}
