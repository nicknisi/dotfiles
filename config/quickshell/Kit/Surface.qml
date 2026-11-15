import QtQuick
import QtQuick.Effects
import qs

// Surface.qml - the island material.
//
// A `surface` fill, a 1 px `hairline` ring drawn inside the edge (a Rectangle
// border sits within its bounds, like CSS `inset 0 0 0 1px`), under whatever
// the surface holds, and on floating surfaces the one shadow, 0 10 28 `shadow`.
// No blur behind it.
//
// Cards inside a floating surface are the same thing grounded:
//     Surface { floating: false; color: Tokens.raised; radius: 14 }
//
// The shadow draws outside the bounds, so a window hosting a floating surface
// needs about 28 px of room on the sides and 38 below.
Rectangle {
    id: root

    property bool floating: true
    property color shadowColor: Tokens.shadow
    property real shadowBlur: 28
    property real shadowOffset: 10

    color: Tokens.surface
    border.color: Tokens.hairline
    border.width: 1

    RectangularShadow {
        z: -1
        anchors.fill: parent
        visible: root.floating
        radius: root.radius
        offset: Qt.vector2d(0, root.shadowOffset)
        blur: root.shadowBlur
        color: root.shadowColor
    }
}
