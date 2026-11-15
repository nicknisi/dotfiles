import QtQuick
import qs
import "../lib/Celestial.js" as Celestial
import "../lib/Spring.js" as Spring

// WorkspaceStrip.qml - the island's workspace letters (rest pill, left zone).
//
// Takes a plain array, so it never touches Hyprland and qmltestrunner can load
// it: items = [{ name, focused, urgent }] in display order, as
// lib/WorkspaceOrder.js shown() returns them. Each name is a 22 x 22 cell
// (gap 2) with its letter in Monaspace Argon 12 / 500, `inkDim`. The focused
// one sits on a FocusShape in `accent` with its letter in `onAccent`.
//
// Delegates are built from the list of names only, and that list is replaced
// only when the names change (sameItems). Hyprland pushes a new workspace list
// on every event, and rebuilding the letters each time was the "Theme is not
// defined" churn ab90116b fixed and the capsule rewrite lost (quickshell-map
// 7). Focus and urgency are bindings on the same delegates. (Qt 6.12's
// Repeater also skips an array equal to its current model; the gate keeps the
// strip from depending on that, and saves re-running everything bound to
// `names` on each push.)
//
// Focus: one shared shape slides to the focused cell on the spatial spring.
// The slide runs lib/Spring.js step() each frame rather than a Behavior, so a
// new focus mid-slide (Super+wheel, quick Super+letter) keeps the shape's
// speed instead of restarting the curve (PLAN 1.5). Reduced motion snaps.
// The first focus keeps the boards' Cookie6Sided; every later one draws a new
// shape from the pool (never the one just shown) and morphs to it.
//
// Clicks and the wheel come out as activated(name): click a letter for that
// workspace; the wheel steps through the shown letters with no wrap, 120 units
// per step so touchpad deltas add up to one notch (Bar.qml's rule).
Item {
    id: root

    property var items: []
    property real cell: 22
    property real gap: 2
    property string shapeName: "Cookie6Sided"
    property var pool: Celestial.POOL
    // Returns 0 <= x < 1. Tests replace it to pick shapes deterministically.
    property var random: Math.random

    signal activated(string name)

    // The delegates' model: the shown names, replaced only when they change.
    property var names: []
    readonly property string focusedName: {
        const list = root.items || [];
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].focused) return String(list[i].name);
        return "";
    }
    readonly property var urgentNames: (root.items || []).filter(i => i && i.urgent && !i.focused).map(i => String(i.name))
    readonly property int focusedIndex: root.names.indexOf(root.focusedName)
    // How many times the delegates were built. Stays put across same-name updates.
    readonly property int builds: strip.builds
    readonly property Item shape: focus
    property real wheelAccumulator: 0

    implicitWidth: names.length > 0 ? names.length * cell + (names.length - 1) * gap : 0
    implicitHeight: cell

    Accessible.role: Accessible.Grouping
    Accessible.name: "Workspaces " + root.names.map(n => n === root.focusedName ? n + " focused" : n).join(", ")

    function sameItems(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++)
            if (a[i] !== b[i]) return false;
        return true;
    }

    function syncNames() {
        const next = (root.items || []).filter(i => i && i.name !== undefined && i.name !== null).map(i => String(i.name));
        if (!sameItems(next, root.names)) root.names = next;
    }
    onItemsChanged: syncNames()
    Component.onCompleted: syncNames()

    // A shape from the pool other than `current`.
    function pickShape(current) {
        const choices = (root.pool || []).filter(n => n !== current);
        if (choices.length === 0) return current;
        const r = Math.min(0.999999, Math.max(0, Number(root.random()) || 0));
        return choices[Math.floor(r * choices.length)];
    }

    QtObject {
        id: focusMemory
        property bool seen: false
    }
    onFocusedNameChanged: {
        if (focusedName === "") return;
        if (focusMemory.seen) root.shapeName = root.pickShape(root.shapeName);
        focusMemory.seen = true;
    }

    function step(delta) {
        wheelAccumulator += delta;
        if (Math.abs(wheelAccumulator) < 120) return;
        const direction = wheelAccumulator < 0 ? 1 : -1;
        wheelAccumulator = 0;
        const index = root.focusedIndex + direction;
        if (root.focusedIndex >= 0 && index >= 0 && index < root.names.length)
            root.activated(root.names[index]);
    }

    WheelHandler {
        onWheel: event => root.step(event.angleDelta.y)
    }

    FocusShape {
        id: focus
        // Slides only once it has a place, so it does not fly in from x 0.
        property bool placed: false
        // Where the focused cell is. x chases it through `slide`, or jumps.
        readonly property real targetX: Math.max(0, root.focusedIndex) * (root.cell + root.gap)
        property real velocity: 0
        readonly property bool sliding: slide.running
        size: root.cell
        shapeName: root.shapeName
        opacity: root.focusedIndex >= 0 ? 1 : 0

        function retarget() {
            if (focus.placed && Motion.spatialOmega < Infinity) {
                if (!slide.running && focus.x !== focus.targetX) slide.start();
                return;
            }
            slide.stop();
            focus.velocity = 0;
            focus.x = focus.targetX;
        }
        onTargetXChanged: retarget()

        FrameAnimation {
            id: slide
            onTriggered: {
                const next = Spring.step(focus.x, focus.velocity, focus.targetX, frameTime, Motion.spatialOmega);
                if (Spring.settled(next.value, next.velocity, focus.targetX)) {
                    focus.velocity = 0;
                    focus.x = focus.targetX;
                    stop();
                } else {
                    focus.velocity = next.velocity;
                    focus.x = next.value;
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        Connections {
            target: root
            function onFocusedIndexChanged() {
                if (root.focusedIndex >= 0 && !focus.placed) Qt.callLater(() => focus.placed = true);
            }
        }
        Component.onCompleted: {
            focus.x = focus.targetX;
            if (root.focusedIndex >= 0) Qt.callLater(() => focus.placed = true);
        }
    }

    Repeater {
        id: strip
        property int builds: 0
        model: root.names

        delegate: Item {
            id: letter
            required property string modelData
            required property int index
            readonly property bool focused: modelData === root.focusedName
            readonly property bool urgent: root.urgentNames.indexOf(modelData) >= 0

            x: index * (root.cell + root.gap)
            width: root.cell
            height: root.cell
            Component.onCompleted: strip.builds++

            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + modelData + (focused ? ", focused" : urgent ? ", needs attention" : "")
            Accessible.onPressAction: root.activated(modelData)

            Text {
                anchors.centerIn: parent
                text: letter.modelData
                font.family: "Monaspace Argon"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: letter.focused ? Tokens.onAccent : letter.urgent ? Tokens.accent : pointer.containsMouse ? Tokens.fg : Tokens.inkDim
                Accessible.ignored: true
                Behavior on color {
                    ColorAnimation {
                        duration: Motion.effects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spring
                    }
                }
            }
            // A window here asks for attention: accent letter and a dot under the cell.
            Rectangle {
                visible: letter.urgent
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 1
                width: 4
                height: 4
                radius: 2
                color: Tokens.accent
            }
            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated(letter.modelData)
            }
        }
    }
}
