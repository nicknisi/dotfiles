import QtQuick
import qs.Commons

Rectangle {
    id: root
    property var borderSpec: Border.none()
    readonly property real borderTop: border.width
    readonly property real borderRight: border.width
    readonly property real borderBottom: border.width
    readonly property real borderLeft: border.width
    border.width: borderSpec ? Math.max(0, borderSpec.width || 0) : 0
    border.color: borderSpec && borderSpec.color ? borderSpec.color : "transparent"
}
