// Reserve the bar thickness and inset along its active screen edge.
//
// The one owner of the exclusive zone in every bar mode: the bar, the island
// and their popups all ignore exclusion. Theme.barExtent is 56 for the pill,
// 40 for the flush full strip and rail (M4) and 46 for the island. Prefs.edge
// is the edge the mode draws on (the island and the full strip read "top", the
// rail "left" unless it is on the right), so a mode switch moves this window
// with the bar, and leaving the island returns it to the remembered edge.
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
