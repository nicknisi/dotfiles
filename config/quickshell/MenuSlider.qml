// Native pointer and keyboard behavior, with a theme-colored track and thumb.
// The service remains the source of truth. Dragging only emits moved(value).
import QtQuick
import QtQuick.Controls

Item {
    id: slider

    property real value: 0
    property color tint: Theme.accent
    property string label: "Level"
    signal moved(real value)
    implicitWidth: 120
    implicitHeight: 28

    Slider {
        id: control
        anchors.fill: parent
        from: 0
        to: 1
        stepSize: 0.01
        value: slider.value
        leftPadding: 6
        rightPadding: 6
        focusPolicy: Qt.StrongFocus
        Accessible.name: slider.label
        onMoved: slider.moved(value)

        background: Rectangle {
            x: control.leftPadding
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: control.availableWidth
            height: 6
            radius: 3
            color: Qt.tint(Theme.raised, Qt.rgba(slider.tint.r, slider.tint.g, slider.tint.b, 0.18))

            Rectangle {
                width: parent.width * control.visualPosition
                height: parent.height
                radius: 3
                color: slider.tint
            }
        }

        handle: Rectangle {
            x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
            y: control.topPadding + control.availableHeight / 2 - height / 2
            width: 12
            height: control.pressed ? 22 : 16
            radius: control.pressed ? 5 : 6
            color: slider.tint
            border.width: control.visualFocus ? 2 : 0
            border.color: Theme.fg
            Behavior on height { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutBack } }
        }
    }
}
