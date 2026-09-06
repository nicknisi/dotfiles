import QtQuick

Item {
    id: mark
    property bool connected: false
    property bool playful: false
    property bool working: false
    property color tint: connected ? Theme.accent : Theme.secondary
    implicitWidth: 18
    implicitHeight: 18

    // The nine dots loosen on hover, then settle back into the Tailscale mark.
    Repeater {
        model: 9
        Rectangle {
            required property int index
            readonly property int column: index % 3
            readonly property int row: Math.floor(index / 3)
            width: 4
            height: 4
            radius: 2
            x: (mark.width - 16) / 2 + column * 6 + (mark.playful ? (column - 1) * 1.5 : 0)
            y: (mark.height - 16) / 2 + row * 6 + (mark.playful ? [0, -2, 1][column] : 0)
            color: mark.tint
            opacity: (index === 0 || index === 3 || index === 4 || index === 6 || index === 7 || index === 8) ? 1 : 0.25
            Behavior on x { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: Theme.base } }
            SequentialAnimation on scale {
                running: mark.working
                loops: Animation.Infinite
                PauseAnimation { duration: index * 55 }
                NumberAnimation { to: 0.45; duration: 220 }
                NumberAnimation { to: 1; duration: 220 }
                PauseAnimation { duration: (8 - index) * 55 }
                onStopped: scale = 1
            }
        }
    }
}
