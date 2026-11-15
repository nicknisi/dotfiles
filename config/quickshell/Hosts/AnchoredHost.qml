import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs

// AnchoredHost.qml - the window around Hosts/AnchoredView.qml, the classic
// bars' panel host (PLAN M4, island-modes 12.4): the control center, its
// sheets, the power menu, the calendar and the old Hud's last pages, against
// the clicked module. One per bar (Bar.qml).
//
// A full-screen Overlay layer, mapped while a panel shows, whose input region
// is the panel alone (the whole screen under the power menu's scrim), so the
// bar and the desktop stay clickable around it. Keys come through a
// HyprlandFocusGrab over this window and the bar's: a click anywhere else
// closes the panel, and a click on the bar's own modules switches or closes
// it there. keyboardFocus stays OnDemand: changing it while the grab is
// active ends the grab.
PanelWindow {
    id: host

    // The Bar window (for the focus grab and the screen) and its BarView.
    required property var barWindow
    required property Item view
    // Where the bar window's top-left sits on the screen.
    property point barOrigin: Qt.point(0, 0)
    property date now: new Date()
    // shell.qml's ThemePicker: Appearance's Theme packs, the control center's
    // Theme mini and `bar open theme` open it on this screen (M7).
    property var pickerHost: null

    readonly property alias content: anchored
    readonly property bool shown: anchored.shown
    readonly property real seamFrom: anchored.seamFrom
    readonly property real seamTo: anchored.seamTo
    readonly property bool seamStartLine: anchored.seamStartLine
    readonly property bool seamEndLine: anchored.seamEndLine

    function open(state: string): string {
        return anchored.open(state);
    }
    function toggle(state: string): string {
        return anchored.toggle(state);
    }
    function close(): void {
        anchored.close();
    }
    function inspect(): var {
        return anchored.inspect();
    }

    screen: barWindow.screen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: anchored.kind !== ""
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-anchored"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property Region openMask: Region {
        item: anchored.hitItem
    }
    property Region noMask: Region {}
    mask: anchored.shown ? host.openMask : host.noMask

    HyprlandFocusGrab {
        windows: [host, host.barWindow]
        active: anchored.shown && host.visible
        onCleared: anchored.close()
    }

    AnchoredView {
        id: anchored
        anchors.fill: parent
        view: host.view
        monitor: host.barWindow.screen
        barOrigin: host.barOrigin
        now: host.now
        pickerHost: host.pickerHost
    }
}
