import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import "../lib/IslandMachine.js" as IslandMachine
import "../lib/WorkspaceOrder.js" as WorkspaceOrder

// Island.qml - the island's window on one screen (PLAN 1.6, island-modes 3.3).
//
// A transparent layer-shell strip across the top: 8 (top inset) + 560 (the
// tallest state, cc) + 40 (room for the 0 10 28 shadow) = 608 high, ignoring
// exclusion (Reserve.qml holds the zone, 46 in island mode). The input mask is
// the body's rounded rectangle, so everything else on the strip passes clicks
// through to the windows under it, and the mask follows the body as it morphs.
//
// While a panel is open (pinned hover in M1), or a Hud hand-off opened from
// IPC, a Hyprland focus grab takes the pointer: a click anywhere outside the
// island (and that Hud) clears the grab, which dismisses it. Namespace quickshell-island is outside hyprland.lua's
// shell-blur rule on purpose (island-modes C6).
//
// After a minute without input (ext-idle-notify, respecting idle inhibitors)
// the Crew's bots hold still (IslandView.ambient), so an agent waiting on an
// unattended screen does not keep the island redrawing.
//
// The drawing and the state live in IslandView; this file adds what needs a
// compositor: the window, the grab, idle and the Hyprland workspaces.
PanelWindow {
    id: island

    required property var modelData
    readonly property alias view: view

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: IslandMachine.WINDOW_HEIGHT
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region {
        item: view.body
        radius: view.body.radius
    }

    // The strip's records: fixture workspaces in the sandbox, Hyprland's otherwise.
    readonly property var workspaceItems: {
        const fixture = Fixture.data.workspaces;
        if (Array.isArray(fixture)) return WorkspaceOrder.shown(fixture, Fixture.data.focused ?? "");
        const records = Hyprland.workspaces.values.map(w => ({
            name: w.name,
            windows: w.toplevels?.values?.length ?? 0,
            urgent: w.urgent === true
        }));
        return WorkspaceOrder.shown(records, Hyprland.focusedWorkspace?.name ?? "");
    }

    function activateWorkspace(name: string): void {
        if (Array.isArray(Fixture.data.workspaces)) return;
        const workspace = Hyprland.workspaces.values.find(w => w.name === name);
        workspace?.activate();
    }

    IslandView {
        id: view
        anchors.fill: parent
        monitor: island.screen
        workspaces: island.workspaceItems
        dpr: island.devicePixelRatio > 0 ? island.devicePixelRatio : 1
        ambient: !idle.isIdle
        onWorkspaceActivated: name => island.activateWorkspace(name)
    }

    IdleMonitor {
        id: idle
        timeout: 60
    }

    // The pinned panel, or a Hud opened from IPC without its own popup grab
    // (IslandView.hudNeedsGrab): either way an outside click clears the grab.
    HyprlandFocusGrab {
        id: grab
        windows: view.hudNeedsGrab ? [island, view.hud] : [island]
        active: view.panelOpen || view.hudNeedsGrab
        onCleared: view.dismiss()
    }
}
