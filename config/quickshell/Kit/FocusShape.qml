import QtQuick
import QtQuick.Shapes
import qs
import "../lib/Celestial.js" as Celestial

// FocusShape.qml - the shape behind the focused workspace's letter.
//
// One of the Celestial shapes (lib/Celestial.js), filled `accent` by default
// and drawn in the boards' 100-unit box scaled to `size`, with overflow
// visible: a shape's radii can pass 0.5, so it may reach a little outside its
// box, as the SVG does.
//
// Setting shapeName morphs to the new shape: the 72 radii blend from wherever
// the shape is now to the new ones over Motion.spatial on the spring, and the
// path is rebuilt every frame (72 points, cheap). A change mid-morph starts
// from the blend on screen, so nothing jumps. Reduced motion (Motion.spatial 0)
// swaps it at once.
//
// Decorative: hidden from accessibility. The strip names the focused workspace.
Item {
    id: root

    property string shapeName: "Cookie6Sided"
    property real size: 22
    property color color: Tokens.accent

    // The shape it is leaving, and how far the morph has come (1 when settled).
    readonly property string previousShapeName: morphState.previous
    readonly property real progress: morphState.progress
    readonly property bool morphing: morph.running
    // Settled, it is the target's own path: from + (to - from) * 1 can miss
    // `to` in the last bit and print a coordinate a tenth off.
    readonly property string path: morphState.to === null || morphState.progress >= 1 ? Celestial.path(root.shapeName)
        : Celestial.pathFromRadii(Celestial.lerpRadii(morphState.from, morphState.to, morphState.progress))

    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true

    QtObject {
        id: morphState
        property var from: null
        property var to: null
        property real progress: 1
        property string current: ""
        property string previous: ""
    }

    // Starts as the declared shape: no morph at creation.
    Component.onCompleted: {
        morphState.current = root.shapeName;
        morphState.previous = root.shapeName;
        morphState.from = Celestial.radii(root.shapeName);
        morphState.to = morphState.from;
    }

    onShapeNameChanged: {
        if (morphState.to === null || shapeName === morphState.current) return;
        const onScreen = Celestial.lerpRadii(morphState.from, morphState.to, morphState.progress);
        morph.stop();
        morphState.previous = morphState.current;
        morphState.current = shapeName;
        morphState.from = onScreen;
        morphState.to = Celestial.radii(shapeName);
        morphState.progress = 0;
        morph.start();
    }

    NumberAnimation {
        id: morph
        target: morphState
        property: "progress"
        from: 0
        to: 1
        duration: Motion.spatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    // Drawn by the default renderer into an 8x multisampled layer. At 22
    // logical px (33 device px) Shape.CurveRenderer stippled the flat sides and
    // left a dotted halo on the many-lobed shapes. The layer is `pad` larger
    // than the box on every side, so the little a shape reaches past its box
    // is not clipped by the layer's bounds.
    Item {
        id: canvas
        readonly property real pad: 2
        x: -pad
        y: -pad
        width: root.width + 2 * pad
        height: root.height + 2 * pad
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true

        Shape {
            x: canvas.pad
            y: canvas.pad
            width: root.width
            height: root.height

            ShapePath {
                scale: Qt.size(root.width / 100, root.height / 100)
                fillColor: root.color
                strokeColor: "transparent"
                strokeWidth: -1
                PathSvg { path: root.path }
            }
        }
    }
}
