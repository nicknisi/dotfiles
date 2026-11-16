import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.Kit
import qs.Island

// PolkitWindow.qml - a polkit request in the classic bar modes (PLAN M8).
//
// Island mode draws the request as the island's `polkit` state; the pill,
// full and rail bars have no island, so this full-screen window does it: the
// scrim, and Island/PolkitLayer.qml on a Surface (480 x 272, radius 28) top
// centre where a classic free panel goes (PLAN 1.6, Launcher.qml's rule): 8
// under the bar's reserved zone when the bar is on the top edge, else 8 under
// the screen's top. Overlay layer, Exclusive keyboard while the request
// waits, so the field has the keys.
//
// The scrim and the card fade in and out over Motion.effects (island-modes:
// the scrim's opacity on the effects spring), the card's content on the
// enter and leave rule (Kit/Layer); the window stays mapped until the fade
// has run, then unmaps. shell.qml builds it only while ShellServices has a
// flow (or this window is still fading out) and the bar is not the island;
// the flow exists only with the agent on (Prefs.polkitAgent) or a sandbox
// fixture.
PanelWindow {
    id: win

    property var flow: null
    // The screen focused when the request started; "" for the first.
    property string screenName: ""

    readonly property bool waiting: win.flow !== null && win.flow.isCompleted !== true
    // Set just after the window is built, so the scrim and the card fade in
    // rather than start at full opacity.
    property bool arrived: false
    readonly property bool shown: win.waiting && win.arrived
    // Still on screen: waiting, or fading out.
    readonly property bool showing: win.waiting || dim.opacity > 0
    Component.onCompleted: Qt.callLater(() => win.arrived = true)
    readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
    readonly property real topY: Prefs.barMode !== "island" && Prefs.edge === "top" ? Theme.barExtent + 8 : 8
    readonly property alias card: card
    readonly property alias layer: layer

    // `polkit inspect`'s window (ShellServices): where the card sits and
    // whether the field has the keys. Never the typed answer: only its length,
    // and only in the sandbox (Fixture.sandbox), for the key runs.
    function inspect(): var {
        return {
            waiting: win.waiting,
            shown: win.shown,
            screen: win.screen?.name ?? "",
            card: { x: card.x, y: card.y, width: card.width, height: card.height },
            typed: Fixture.sandbox ? layer.buffer.length : -1,
            fieldFocus: layer.field.activeFocus,
            keyboardHere: layer.field.keyboardHere
        };
    }

    screen: Quickshell.screens.find(s => s.name === win.screenName) ?? Quickshell.screens[0] ?? null
    visible: win.showing
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.waiting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Tokens.scrim
        opacity: win.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }
    // A click outside the card cancels, as an outside click does on the island.
    MouseArea {
        anchors.fill: parent
        enabled: win.waiting
        onClicked: layer.cancel()
    }

    Surface {
        id: card
        // On whole device pixels: at scale 1.5 an odd logical offset splits
        // the 1 px ring across two device rows.
        x: Math.round((win.width - width) / 2 * win.dpr) / win.dpr
        y: Math.round(win.topY * win.dpr) / win.dpr
        width: 480
        height: 272
        radius: 28
        opacity: dim.opacity
        MouseArea {
            anchors.fill: parent
        }
        PolkitLayer {
            id: layer
            current: win.shown
            flow: win.flow
            user: Quickshell.env("USER") ?? ""
            faceSources: Face.urls
        }
    }
}
