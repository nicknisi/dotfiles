// Reserve.qml - the space the capsule keeps windows out of.
//
// A 1px transparent window that does nothing but carry the exclusive zone. It
// is separate from Bar.qml so the capsule's own window can let go of its edge
// and cover the screen while you drag it, without the zone going with it and
// every window on the desktop reflowing under your pointer. Re-anchoring this
// is the one reflow a move costs, and it happens on the drop.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top:    Prefs.edge === "top"
        bottom: Prefs.edge === "bottom"
        left:   Prefs.edge === "left"
        right:  Prefs.edge === "right"
    }
    exclusiveZone: Theme.barHeight + 4
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "quickshell-capsule-reserve"
}
