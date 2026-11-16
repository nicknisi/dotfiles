import QtQuick

// ScreenCornerSet.qml - the four ScreenCorner wedges in the corners of the
// item it fills, for a full-screen Overlay surface that paints a scrim
// (WindowSwitcher, PolkitWindow, Hosts/AnchoredView's power menu). Hyprland
// stacks a layer's surfaces in map order, so a scrim mapped after
// ScreenCorners' strips covers their wedges and greys them; the surface
// paints its own on top instead. `radius` is ScreenCorners.drawn (0 while the
// corners are off, or with no ScreenCorners), which tracks the strips through
// a radius change, so the two never differ.
//
// `skipEdge` (top, bottom, left or right) leaves out that edge's two corners,
// where the scrim stops short of the screen's edge (a full strip or the rail
// with its power menu) and the strips' own wedges show: a second antialiased
// arc over the first would darken its edge pixels.
Item {
    id: root

    property real radius: 0
    property string skipEdge: ""

    visible: radius > 0

    ScreenCorner {
        corner: "topLeft"
        radius: root.radius
        visible: root.skipEdge !== "top" && root.skipEdge !== "left"
    }
    ScreenCorner {
        anchors.right: parent.right
        corner: "topRight"
        radius: root.radius
        visible: root.skipEdge !== "top" && root.skipEdge !== "right"
    }
    ScreenCorner {
        anchors.bottom: parent.bottom
        corner: "bottomLeft"
        radius: root.radius
        visible: root.skipEdge !== "bottom" && root.skipEdge !== "left"
    }
    ScreenCorner {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        corner: "bottomRight"
        radius: root.radius
        visible: root.skipEdge !== "bottom" && root.skipEdge !== "right"
    }
}
