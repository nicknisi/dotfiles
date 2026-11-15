import QtQuick
import qs

// Slider.qml - a 6 px `fillHigh` track with an `accent` fill, value 0..1.
// The control center's volume and brightness rows, the OSD (interactive:
// false) and the sheets' small level bars.
//
// Controlled: dragging, the wheel and the arrow keys ask with moved(value) and
// leave `value` alone, so `value: Audio.volume` stays a binding. While a drag
// is held the fill follows the pointer, not the service; when the value
// changes otherwise the fill eases there over Motion.effects.
//
// Steps: `stepSize` per arrow key or wheel notch (5 %, as the media keys
// step), Page Up/Down two steps, Home and End the ends. None of this is drawn
// in the mocks.
Item {
    id: root

    property real value: 0
    property real stepSize: 0.05
    property bool interactive: true
    property int thickness: 6
    property string label: ""
    property color trackColor: Tokens.fillHigh
    property color fillColor: Tokens.accent

    signal moved(real value)

    readonly property bool dragging: mouse.pressed
    readonly property real shown: dragging ? drag.value : clamp(value)
    readonly property real fillWidth: fill.width

    implicitWidth: 110
    implicitHeight: 24
    activeFocusOnTab: interactive && enabled

    function clamp(v) {
        return Math.max(0, Math.min(1, Number(v) || 0));
    }
    function nudge(steps) {
        root.moved(clamp(root.value + steps * root.stepSize));
    }

    QtObject {
        id: drag
        property real value: 0
    }

    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.focusable: interactive
    Accessible.onIncreaseAction: root.nudge(1)
    Accessible.onDecreaseAction: root.nudge(-1)

    Keys.enabled: interactive
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Right: case Qt.Key_Up: nudge(1); break;
        case Qt.Key_Left: case Qt.Key_Down: nudge(-1); break;
        case Qt.Key_PageUp: nudge(2); break;
        case Qt.Key_PageDown: nudge(-2); break;
        case Qt.Key_Home: root.moved(0); break;
        case Qt.Key_End: root.moved(1); break;
        default: return;
        }
        event.accepted = true;
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.thickness
        radius: height / 2
        color: root.trackColor

        Rectangle {
            id: fill
            height: parent.height
            radius: parent.radius
            color: root.fillColor
            width: track.width * root.shown
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation {
                    duration: Motion.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spring
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive && root.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function at(x) {
            return root.clamp((x - track.x) / Math.max(1, track.width));
        }
        onPressed: event => {
            drag.value = at(event.x);
            root.moved(drag.value);
        }
        onPositionChanged: event => {
            if (!pressed) return;
            drag.value = at(event.x);
            root.moved(drag.value);
        }
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            if (delta !== 0) root.nudge(delta / 120);
        }
    }

    FocusRing {
        target: track
    }
}
