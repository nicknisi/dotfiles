import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import "../lib/IslandMachine.js" as IslandMachine
import "../lib/WorkspaceOrder.js" as WorkspaceOrder

// Island.qml - the island's window on one screen (PLAN 1.6, island-modes 3.3).
//
// A transparent layer-shell strip across the top: 8 (top inset) + 600 (the
// tallest state, the themes picker, M7) + 40 (room for the 0 10 28 shadow) =
// 648 high, ignoring exclusion (Reserve.qml holds the zone, 46 in island
// mode). The input mask is
// the body's rounded rectangle, so everything else on the strip passes clicks
// through to the windows under it, and the mask follows the body as it morphs.
//
// While a panel is open (pinned hover, the calendar, the control center, the
// power menu), a Hyprland focus grab takes the pointer and the keyboard: a
// click anywhere outside the island clears the grab, which dismisses it. The power menu shows over a
// full-screen scrim (Scrim.qml), with the island raised to Overlay above it.
// Namespace quickshell-island is outside hyprland.lua's shell-blur rule on
// purpose (island-modes C6); so is quickshell-island-scrim (no blur).
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
    // The session's NotificationServer.qml and the launcher's VoiceSession
    // (shell.qml), for the island's own notif and dict states (M3).
    property var notifications: null
    property var voice: null
    // shell.qml's Launcher: the control center's Clipboard opens the palette
    // in place (IslandView.paletteHost). Not named `launcher`: inside the
    // Island in shell.qml's per-screen delegate that name would then resolve
    // to this property rather than shell.qml's Launcher (the delegate's scope
    // object comes before the file's ids), breaking `voice:` there too.
    property var paletteHost: null
    // shell.qml's ThemePicker (M7): `island open themes` and the control
    // center's Theme mini open the pickers in place (IslandView.pickerHost).
    property var pickerHost: null
    // A polkit request (M8, ShellServices.polkitFlow) and whether this screen
    // shows it (IslandView.polkitFlow, polkitHere).
    property var polkitFlow: null
    property bool polkitHere: true

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
    // Overlay while the power menu or a polkit request shows, so the island
    // is above its scrim (Scrim.qml, on Top), and on through a panel opened
    // over it (the palette, cc) until the island is back to rest
    // (IslandView.raised); Top otherwise, under fullscreen windows' overlays.
    WlrLayershell.layer: view.raised ? WlrLayer.Overlay : WlrLayer.Top
    // OnDemand in every state. The launcher state (M5) gets the keyboard from
    // the focus grab below, which hands it to the grabbing window: changing
    // keyboardFocus while the grab is active ends the grab and so closes the
    // panel it was opened for (seen in the sandbox). The one change is at
    // rest: None for a moment after a panel (the launcher, a picker, cc) when
    // the island kept the keyboard with no window to return it to
    // (IslandView.keyboardDrop).
    WlrLayershell.keyboardFocus: view.keyboardDrop ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

    mask: Region {
        item: view.body
        // The notch's top corners are square on the screen edge (M9).
        radius: view.body.notch ? 0 : view.body.radius
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
        notifications: island.notifications
        voice: island.voice
        paletteHost: island.paletteHost
        pickerHost: island.pickerHost
        polkitFlow: island.polkitFlow
        polkitHere: island.polkitHere
        dpr: island.devicePixelRatio > 0 ? island.devicePixelRatio : 1
        // A fixture's `still` holds the loops too, so a sandbox shot of a
        // breathing dot or sparkle is one colour.
        ambient: !idle.isIdle && Fixture.data.still !== true
        onWorkspaceActivated: name => island.activateWorkspace(name)
    }

    IdleMonitor {
        id: idle
        timeout: 60
    }

    // The dim behind the power menu (M6) and a polkit request (M8).
    Scrim {
        screen: island.screen
        shown: view.scrimShown
        held: view.raised
    }

    // The pinned panel: an outside click clears the grab.
    HyprlandFocusGrab {
        id: grab
        windows: [island]
        active: view.panelOpen && !island.regrabbing
        onCleared: if (!island.regrabbing) view.dismiss()
    }

    // A polkit request (M8) gets the keyboard from the grab above. A grab
    // made while the session is locked never does (M8 review): the lock has
    // the keyboard, and the unlock hands it back to the window focused before
    // the lock, so a password typed into the prompt went to that window. So
    // while a request waits here and this window does not have the keyboard,
    // the grab is made again every 400 ms until it does (once unlocked, the
    // first new grab takes it). The field draws no focus ring or caret
    // meanwhile (Kit/SecretField keyboardHere).
    property bool regrabbing: false
    property int regrabs: 0
    Timer {
        id: regrab
        interval: 400
        repeat: true
        running: view.polkitPending && view.islandState === "polkit" && !view.windowActive
        onTriggered: {
            island.regrabs++;
            island.regrabbing = true;
            Qt.callLater(() => island.regrabbing = false);
        }
    }
}
