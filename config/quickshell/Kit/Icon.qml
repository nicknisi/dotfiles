import QtQuick
import QtQuick.Shapes
import qs
import "IconPaths.js" as IconPaths

// Icon.qml - one stroked icon from IconPaths.js.
//
// 24-unit paths stroked at 1.8 units with round caps and joins, so 1.05 px at
// 14 and 1.2 px at 16. ShapePath.scale scales the coordinates and not the
// stroke (measured in tests/tst_kit.qml and the gallery shot), so the stroke is
// scaled here. Solid icons (media transport) are filled as well.
//
// Decorative: hidden from accessibility. Name the control that holds it.
Item {
    id: root

    property string name: ""
    property real size: 16
    property color color: Tokens.fg
    // Filled as well as stroked. Defaults to the icon's own variant.
    property bool solid: IconPaths.isSolid(name)

    readonly property string path: IconPaths.path(name)
    readonly property real strokeWidth: IconPaths.STROKE * Math.min(width, height) / 24

    implicitWidth: size
    implicitHeight: size
    Accessible.ignored: true

    // IconPaths itself, not `path`: that binding may not have caught up yet.
    onNameChanged: if (name !== "" && IconPaths.path(name) === "") console.warn("Icon: no icon named", name)

    Shape {
        anchors.fill: parent
        visible: root.path !== ""
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            scale: Qt.size(root.width / 24, root.height / 24)
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: root.solid ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
