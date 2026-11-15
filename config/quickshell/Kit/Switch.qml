import QtQuick
import qs

// Switch.qml - a 40 x 24 on/off track with an 18 px knob, 3 px in.
// On: `accent` track, `onAccent` knob on the right. Off: `fillHigh` track,
// `inkDim` knob on the left.
//
// Controlled: a click or Space asks with toggled(on) and leaves `checked`
// alone, so `checked: Net.radioOn` stays a binding and shows what the service
// did. Bind `checked`, handle `onToggled`.
//
// The colours cross-fade by opacity rather than with a colour Behavior, which
// would chase every frame of a theme change Tokens already animates.
Item {
    id: root

    property bool checked: false
    property string label: ""

    signal toggled(bool on)

    implicitWidth: 40
    implicitHeight: 24
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: enabled
    readonly property real radius: height / 2

    Accessible.role: Accessible.Switch
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.focusable: true
    Accessible.onToggleAction: root.toggled(!root.checked)
    Accessible.onPressAction: root.toggled(!root.checked)

    Keys.onPressed: event => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggled(!root.checked);
            event.accepted = true;
        }
    }

    component Fade: NumberAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Tokens.fillHigh
    }
    Rectangle {
        id: onTrack
        anchors.fill: parent
        radius: root.radius
        color: Tokens.accent
        opacity: root.checked ? 1 : 0
        Behavior on opacity { Fade {} }
    }

    Item {
        id: knob
        width: 18
        height: 18
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        Behavior on x {
            NumberAnimation {
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Tokens.inkDim
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Tokens.onAccent
            opacity: onTrack.opacity
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    FocusRing {}
}
