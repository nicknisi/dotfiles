import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
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
//
// A look (M9, Look.qml) swaps the material for its rest bar and moments:
// fill, ring (its width 0 for none), a fixed corner radius, and the shadow,
// or a glow (the shadow's colour at offset 0) in its place. The defaults are
// the plain island's.
//
// The notch form (M9, island-modes 8): the body hangs flush from the top
// edge with square top corners and bottom corners of
// IslandMachine.notchRadius(h), and a Shape paints the 12 px concave
// shoulders out to either side where it meets the edge. Content still clips
// to the body: the ClippingRectangle is already a shader mask (Quickshell
// renders its rectangle into a layer and masks the content with it), and
// with per-corner radii that mask is the notch's own body, so no second
// MultiEffect mask pass is needed; the shoulders hold no content, only fill.
// The hairline runs down the sides from the shoulders and along the bottom,
// never along the screen edge (IslandMachine.notchRingPath), drawn over the
// content like the float form's ring. Its bottom corners are circular arcs
// of the body's own radius, and it is a child of the body itself, outside
// the content's mask: a ring in the mask lost its corners where its curve
// left the circle (M9 review).
//
// A look's material changes with the cell (rest to hover, a moment to a
// panel): the fill, the ring's colour and width and the shadow's colour fade
// on the effects spring (personal-looks 1.3: colour is an effect, 245 ms),
// so Bridge's black body does not turn at t 0 while its segments fade out.
ClippingRectangle {
    id: body

    property real targetWidth: 360
    property real targetHeight: 38
    property bool notch: false
    // The material (M9 looks): the plain island's by default.
    property color fill: Tokens.surface
    property color ring: Tokens.hairline
    property real ringWidth: 1
    // A look's own corner radius; -1 follows the height.
    property real fixedRadius: -1
    property color shadowColor: Tokens.shadow
    property real shadowBlur: 28
    property real shadowOffset: 10
    readonly property real targetRadius: body.fixedRadius >= 0 ? body.fixedRadius : body.notch ? IslandMachine.notchRadius(targetHeight) : IslandMachine.radiusFor(targetHeight)
    readonly property bool morphing: widthMotion.running || heightMotion.running || radiusMotion.running

    // The material's colours and the ring's width, on the effects spring.
    Behavior on fill {
        ColorAnimation {
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    Behavior on ring {
        ColorAnimation {
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    Behavior on shadowColor {
        ColorAnimation {
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    Behavior on ringWidth {
        NumberAnimation {
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }

    // The radius runs on its own property: `radius` is an alias into the
    // ClippingRectangle's inner Rectangle, and a Behavior belongs on a real
    // property.
    property real shownRadius: targetRadius

    width: targetWidth
    height: targetHeight
    radius: shownRadius
    // Per corner, so the notch can square its top two; the float form keeps
    // all four on the radius.
    topLeftRadius: body.notch ? 0 : shownRadius
    topRightRadius: body.notch ? 0 : shownRadius
    bottomLeftRadius: shownRadius
    bottomRightRadius: shownRadius
    color: body.fill
    // The notch draws its ring itself (no top edge).
    border.width: body.notch ? 0 : body.ringWidth
    border.color: body.ring
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
        id: shadow
        parent: body
        z: -1
        anchors.fill: parent
        radius: body.radius
        offset: Qt.vector2d(0, body.shadowOffset)
        blur: body.shadowBlur
        color: body.shadowColor
        visible: body.shadowColor.a > 0
    }

    // The notch's shoulders, outside the body and so outside its clip: each
    // a 12 x 12 fillet from the edge down into the body's side.
    Shape {
        id: shoulders
        parent: body
        z: -1
        visible: body.notch
        x: -IslandMachine.NOTCH_SHOULDER
        width: body.width + 2 * IslandMachine.NOTCH_SHOULDER
        height: IslandMachine.NOTCH_SHOULDER
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: body.fill
            strokeWidth: -1
            PathSvg {
                // Left: (0,0) to (12,12) around the control (12,0); right mirrored.
                readonly property real s: IslandMachine.NOTCH_SHOULDER
                readonly property real w: body.width
                path: "M 0 0 Q " + s + " 0 " + s + " " + s + " L " + s + " 0 Z M " + (w + s) + " 0 L " + (w + s) + " " + s + " Q " + (w + s) + " 0 " + (w + 2 * s) + " 0 Z"
            }
        }
    }

    // The notch's hairline, over the content and outside its mask (a child
    // of the body, z above the content item).
    Shape {
        id: notchRing
        parent: body
        z: 1
        visible: body.notch && body.ringWidth > 0
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: body.ring
            strokeWidth: body.ringWidth
            capStyle: ShapePath.FlatCap
            PathSvg {
                path: IslandMachine.notchRingPath(body.width, body.height, body.shownRadius, body.ringWidth)
            }
        }
    }

    readonly property alias shoulders: shoulders
    readonly property alias notchRing: notchRing
    readonly property alias shadow: shadow
}
