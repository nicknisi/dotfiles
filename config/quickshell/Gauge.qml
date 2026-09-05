// Gauge.qml - a level, as a filled column.
//
// Memory is not a rate. Its sparkline was a flat band that never told you
// anything the number would not have, so it gets the shape that suits a level
// instead: a track that is always the same height with a fill that is not.
//
// Sitting next to Spark, the difference in shape is also what tells the two
// apart at a glance, which two identically-shaped strips never did.
import QtQuick

Item {
    id: gauge

    property real value: 0   // 0..100
    property color tint: Theme.fg

    implicitWidth: 5
    implicitHeight: 14

    Rectangle {
        anchors.fill: parent
        color: gauge.tint
        opacity: 0.18
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(1, parent.height * Math.max(0, Math.min(1, gauge.value / 100)))
        color: gauge.tint

        Behavior on height {
            NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic }
        }
    }
}
