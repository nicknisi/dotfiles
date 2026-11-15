// Reserve the bar thickness and inset along its active screen edge.
//
// The one owner of the exclusive zone in every bar mode: the bar, the island
// and their popups all ignore exclusion. Theme.barExtent is 56 for pill and
// rail, 40 for full and 46 for the island. Prefs.edge reads "top" in island
// mode, so switching to the island moves this window to the top edge, and
// leaving it returns the window to the remembered edge.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: reserve
    required property var modelData
    screen: modelData
    anchors {
        top: Prefs.edge === "top"
        bottom: Prefs.edge === "bottom"
        left: Prefs.edge === "left"
        right: Prefs.edge === "right"
    }
    // This transparent surface needs the same remap as the visible bar.
    onAnchorsChanged: {
        reserve.visible = false;
        Qt.callLater(() => reserve.visible = true);
    }
    exclusiveZone: Theme.barExtent
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "quickshell-capsule-reserve"
}
