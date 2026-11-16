import QtQuick
import qs

// Layer.qml - a content layer arriving and leaving, the one implementation of
// the choreography every island state, sheet and panel uses (PLAN 1.5,
// main-tokens 2.3):
//
//   enter  visible at once; opacity 0 -> 1 over Motion.effects on the spring,
//          after Motion.stagger; translateY -6 -> 0 over Motion.spatial.
//   leave  input and accessibility off at once; opacity -> 0 over
//          Motion.exitFade, linear; translateY -> -6 over Motion.spatial;
//          visible false once the fade ends.
//
// The outgoing layer is gone by 123 ms and the incoming one starts at 80, so
// they overlap for about 43 ms while the host is still changing size.
//
// Lay a layer out at its state's final size, anchored to the host's top edge
// and centred, and let the host clip it while it morphs. A layer that is
// current when created shows at once, so the island does not fade in at login.
// Reversing mid-flight continues from wherever opacity and offset are.
Item {
    id: root

    property bool current: false
    // How far above its place a layer starts and ends, in px.
    property real slide: 6

    readonly property bool animating: enter.running || leave.running
    readonly property alias offset: shift.y

    visible: false
    opacity: 0
    enabled: current
    Accessible.ignored: !current
    transform: Translate {
        id: shift
        y: -root.slide
    }

    // A `current: true` in the declaration is a start state, not an arrival:
    // changes count only once the layer exists.
    QtObject {
        id: created
        property bool done: false
    }
    onCurrentChanged: {
        if (created.done) current ? arrive() : depart();
    }

    function arrive() {
        leave.stop();
        visible = true;
        enter.restart();
    }

    function depart() {
        enter.stop();
        if (!visible) {
            opacity = 0;
            shift.y = -slide;
            return;
        }
        leave.restart();
    }

    Component.onCompleted: {
        if (current) {
            opacity = 1;
            shift.y = 0;
            visible = true;
        }
        created.done = true;
    }

    ParallelAnimation {
        id: enter
        SequentialAnimation {
            PauseAnimation { duration: Motion.stagger }
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        NumberAnimation {
            target: shift
            property: "y"
            to: 0
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }

    ParallelAnimation {
        id: leave
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: Motion.exitFade
                easing.type: Easing.Linear
            }
            PropertyAction { target: root; property: "visible"; value: false }
        }
        NumberAnimation {
            target: shift
            property: "y"
            to: -root.slide
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
}
