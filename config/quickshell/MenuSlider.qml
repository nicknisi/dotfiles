// MenuSlider.qml - a value between 0 and 1, dragged.
//
// No knob. Everything else on this desktop is a rectangle with a hard edge, and
// a floating circle would be the only round thing in the shell. The accent tick
// at the fill edge does the job a knob would: it says where the value is and it
// is what your eye follows while dragging.
//
// It does not write to `value` itself. The owner sets that from wherever the
// truth lives (PipeWire, in practice) and reacts to `moved`, so the slider can
// never disagree with the thing it controls.
import QtQuick
import QtQuick.Layouts

Item {
    id: slider

    property real value: 0
    property color tint: Theme.accent
    signal moved(real value)

    implicitHeight: 16
    implicitWidth: 120

    function setFrom(x) {
        slider.moved(Math.max(0, Math.min(1, x / slider.width)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        color: slider.tint
        opacity: 0.2
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, slider.value))
        height: 4
        color: slider.tint

        Behavior on width {
            enabled: !drag.pressed
            NumberAnimation { duration: Theme.quick }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(parent.width - width, fill.width)
        width: Theme.borderWidth
        height: parent.height
        color: slider.tint
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onPressed: event => slider.setFrom(event.x)
        onPositionChanged: event => { if (drag.pressed) slider.setFrom(event.x) }
    }
}
