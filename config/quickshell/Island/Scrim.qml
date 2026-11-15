import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Scrim.qml - the full-screen dim behind the power menu (PLAN M6, DECISION
// 5's default: `rgba(bg, .56)`, Tokens.scrim; opaque surfaces, no blur).
//
// A layer-shell window of its own on the Top layer, covering the screen and
// ignoring exclusion. Its input mask is empty, so it never takes a click:
// the island's focus grab is what closes the menu on an outside click. While
// it shows, Island.qml raises the island to Overlay so the island sits above
// it (PLAN risk 11: `hyprctl layers` lists quickshell-island-scrim on Top and
// quickshell-island on Overlay). The dim fades over Motion.effects; the
// window unmaps once it has faded out.
PanelWindow {
    id: scrim

    property bool shown: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-island-scrim"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: scrim.shown || dim.opacity > 0
    mask: Region {}

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Tokens.scrim
        opacity: scrim.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }
}
