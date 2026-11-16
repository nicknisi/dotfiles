import QtQuick
import QtQuick.Effects
import qs

// AnchoredFrame.qml - the material of a panel anchored to the classic bar
// (PLAN M4, island-modes 12.4): the island's `surface` fill, its 1 px
// `hairline` and its one shadow (0 10 28 `shadow`), drawn with the corners and
// sides lib/Anchored.js gives for the panel's place.
//
//   shape     Anchored.place()'s result: radii (28 on a free corner, 0 where
//             the panel meets the bar or a screen edge), hairline (the sides
//             to draw) and seam (the side against a flush strip, "" for the
//             pill).
//   panel*    where the panel is drawn now, in this item's coordinates. The
//             host moves it: grow (the pill: from the module's size at the
//             aligned corner), drop and slide (full and rail: in from behind
//             the strip).
//   seamAt    the bar's inner edge, in this item's coordinates. With a seam,
//             the panel and its shadow are cut off there, so a panel sliding
//             out from behind the strip never draws over it.
//   content*  the content's final rectangle. `pinned` (grow) keeps the
//             content there while the panel grows over it, so the clip
//             reveals it from the corner and nothing reflows; otherwise the
//             content rides with the panel.
//
// A hairline side that is left open is pushed 2 px outside the panel and
// clipped, so the drawn sides end square at the seam and run into the round
// corner on the other end. QtQuick only: no Quickshell import, so
// tests/tst_anchored_corners.qml renders it under qmltestrunner.
Item {
    id: frame

    property var shape: null
    property real panelX: 0
    property real panelY: 0
    property real panelWidth: 0
    property real panelHeight: 0
    property real seamAt: 0
    property real contentX: panelX
    property real contentY: panelY
    property real contentWidth: panelWidth
    property real contentHeight: panelHeight
    property bool pinned: false
    // Draw the shadow (hidden in tests that sample pixels near the edges).
    property bool shadowed: true

    default property alias content: holder.data

    readonly property string seam: frame.shape?.seam ?? ""
    readonly property var hairline: frame.shape?.hairline ?? ({ top: true, right: true, bottom: true, left: true })
    // A corner is never rounder than half the panel, while it grows from a
    // module's 32 px.
    readonly property real maxRadius: Math.min(frame.panelWidth, frame.panelHeight) / 2
    function radius(name: string): real {
        return Math.min(frame.shape?.radii?.[name] ?? 0, frame.maxRadius);
    }
    // What is drawn, for the tests and the host's inspect().
    readonly property var drawn: ({
            radii: { topLeft: fill.topLeftRadius, topRight: fill.topRightRadius, bottomRight: fill.bottomRightRadius, bottomLeft: fill.bottomLeftRadius },
            hairline: { top: ring.y >= 0, right: ring.x + ring.width <= panel.width, bottom: ring.y + ring.height <= panel.height, left: ring.x >= 0 }
        })
    // Where the content holder's top-left sits, in this item's coordinates
    // (the host keeps an outgoing layer still against it).
    readonly property real holderX: frame.pinned ? frame.contentX : frame.panelX
    readonly property real holderY: frame.pinned ? frame.contentY : frame.panelY
    readonly property alias panel: panel
    readonly property alias fill: fill
    readonly property alias ring: ring
    readonly property alias holder: holder

    // Everything on the panel's side of the seam.
    Item {
        id: limit
        clip: frame.seam !== ""
        x: frame.seam === "left" ? frame.seamAt : 0
        y: frame.seam === "top" ? frame.seamAt : 0
        width: frame.seam === "left" ? frame.width - frame.seamAt : frame.seam === "right" ? frame.seamAt : frame.width
        height: frame.seam === "top" ? frame.height - frame.seamAt : frame.seam === "bottom" ? frame.seamAt : frame.height

        Item {
            id: panel
            x: frame.panelX - limit.x
            y: frame.panelY - limit.y
            width: frame.panelWidth
            height: frame.panelHeight

            RectangularShadow {
                z: -1
                visible: frame.shadowed && panel.width > 0 && panel.height > 0
                anchors.fill: parent
                radius: Math.max(fill.topLeftRadius, fill.topRightRadius, fill.bottomRightRadius, fill.bottomLeftRadius)
                offset: Qt.vector2d(0, 10)
                blur: 28
                color: Tokens.shadow
            }
            Rectangle {
                id: fill
                anchors.fill: parent
                color: Tokens.surface
                topLeftRadius: frame.radius("topLeft")
                topRightRadius: frame.radius("topRight")
                bottomRightRadius: frame.radius("bottomRight")
                bottomLeftRadius: frame.radius("bottomLeft")
            }
            // The content, clipped to the panel's box (its 16 px padding keeps
            // it clear of the round corners).
            Item {
                id: clipper
                anchors.fill: parent
                clip: true
                Item {
                    id: holder
                    x: frame.pinned ? frame.contentX - frame.panelX : 0
                    y: frame.pinned ? frame.contentY - frame.panelY : 0
                    width: frame.contentWidth
                    height: frame.contentHeight
                }
            }
            // The hairline, over the content like the island's opaque ring.
            Item {
                anchors.fill: parent
                clip: true
                Rectangle {
                    id: ring
                    readonly property real l: frame.hairline.left ? 0 : 2
                    readonly property real r: frame.hairline.right ? 0 : 2
                    readonly property real t: frame.hairline.top ? 0 : 2
                    readonly property real b: frame.hairline.bottom ? 0 : 2
                    x: -l
                    y: -t
                    width: parent.width + l + r
                    height: parent.height + t + b
                    color: "transparent"
                    border.width: 1
                    border.color: Tokens.hairline
                    topLeftRadius: fill.topLeftRadius
                    topRightRadius: fill.topRightRadius
                    bottomRightRadius: fill.bottomRightRadius
                    bottomLeftRadius: fill.bottomLeftRadius
                }
            }
        }
    }
}
