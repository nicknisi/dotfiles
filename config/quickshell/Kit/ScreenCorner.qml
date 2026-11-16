import QtQuick
import qs

// ScreenCorner.qml - one corner of a rounded screen: the wedge between the
// screen's corner and a quarter circle of `radius`, in Tokens.bezel, as if
// the panel itself were rounded. ScreenCorners.qml puts one in each corner of
// every screen. `corner` is topLeft, topRight, bottomLeft or bottomRight.
//
// The arc is a Rectangle's inner border edge: a transparent 2r square with
// corner radius r, ringed by a border r wide (so its outer radius is 2r),
// placed with the arc's centre r in from both screen edges and clipped to
// this r x r box. Qt antialiases a rounded border on the GPU and on the
// software backend alike (tests/tst_kit.qml reads its pixels), and nothing
// here animates or repaints by itself.
Item {
    id: root

    property string corner: "topLeft"
    property real radius: 14
    property color color: Tokens.bezel
    // Not `right` or `bottom`: those would shadow the anchor lines.
    readonly property bool atRight: corner === "topRight" || corner === "bottomRight"
    readonly property bool atBottom: corner === "bottomLeft" || corner === "bottomRight"

    width: radius
    height: radius
    visible: radius > 0
    clip: true

    Rectangle {
        x: root.atRight ? -2 * root.radius : -root.radius
        y: root.atBottom ? -2 * root.radius : -root.radius
        width: 4 * root.radius
        height: 4 * root.radius
        radius: 2 * root.radius
        color: "transparent"
        border.width: root.radius
        border.color: root.color
        antialiasing: true
    }
}
