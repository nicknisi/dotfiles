// Reserve the bar thickness and inset along its active screen edge.
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
