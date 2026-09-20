import QtQuick

Rectangle {
    // Follows the capsule's see-through mode, so the HUD, the launcher and the
    // notification center read as one material with the pill.
    property color fill: Theme.alpha(Theme.surface, Theme.surfaceOpacity)
    property bool prominent: false
    property color outlineColor: prominent ? Theme.alpha(Theme.fg, 0.18) : Theme.borderIdle
    property real outlineWidth: 1

    radius: Theme.panelRadius
    color: fill
    border.width: outlineWidth
    border.color: outlineColor
}
