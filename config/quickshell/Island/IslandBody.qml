import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import "../lib/IslandMachine.js" as IslandMachine

// IslandBody.qml - the island's one surface, which becomes every state.
//
// Set targetWidth and targetHeight to the state's size; width, height and
// radius follow over Motion.spatial on the spring, the radius toward
// min(28, h / 2), so the rest pill (38 high) is fully round at 19 and every
// taller state settles at 28. The three run on one curve, which is what the
// Main board's CSS transition does, so mid-morph the corners are a little
// tighter than h / 2.
//
// The material is Kit/Surface's: `surface` fill, a 1 px `hairline` ring inside
// the edge, and the one shadow, 0 10 28 `shadow`. A ClippingRectangle (not
// Item.clip, which clips to the bounding box) keeps content inside the rounded
// shape while it morphs. Content sits in the full rectangle (contentUnderBorder),
// so a layer at y 0 is at the island's top edge; the ring is opaque, so content
// never shows through it.
//
// Children are the state layers (Kit/Layer), each laid out at its own final
// size, anchored to the top edge and centred: the body reveals them as it grows.
ClippingRectangle {
    id: body

    property real targetWidth: 360
    property real targetHeight: 38
    readonly property real targetRadius: IslandMachine.radiusFor(targetHeight)
    readonly property bool morphing: widthMotion.running || heightMotion.running || radiusMotion.running

    // The radius runs on its own property: `radius` is an alias into the
    // ClippingRectangle's inner Rectangle, and a Behavior belongs on a real
    // property.
    property real shownRadius: targetRadius

    width: targetWidth
    height: targetHeight
    radius: shownRadius
    color: Tokens.surface
    border.width: 1
    border.color: Tokens.hairline
    contentUnderBorder: true

    Behavior on width {
        NumberAnimation {
            id: widthMotion
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    Behavior on height {
        NumberAnimation {
            id: heightMotion
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    Behavior on shownRadius {
        NumberAnimation {
            id: radiusMotion
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }

    // Under the surface, outside the clip: a child of the body itself, not of
    // its content item (where the default property would put it).
    RectangularShadow {
        parent: body
        z: -1
        anchors.fill: parent
        radius: body.radius
        offset: Qt.vector2d(0, 10)
        blur: 28
        color: Tokens.shadow
    }
}
