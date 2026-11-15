import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs

// BarIpc.qml - `qs ipc call bar ...`: the classic bars' anchored panels
// (Hosts/AnchoredHost.qml, PLAN M4), as `island` drives the island's.
//
// Lives in shell.qml in every bar mode. The verbs act on the bar of the
// focused monitor (the first one when Hyprland cannot say) and answer
// "error: ..." in island mode, where `island open` does the same.
//
//   open STATE    cc | cc/<sheet> (wifi, sound, tailscale, bt, notifications,
//                 display, awake, tray) | power | cal | battery | appearance |
//                 theme. cc and its sheets, power and the pages hang from the
//                 status module, cal from the clock. Opened this way, the
//                 first control draws its focus ring.
//   close         closes whatever is open
//   toggle STATE  open, or close when that panel is already showing
//   inspect       JSON: mode, edges, the reserve and every bar's host (the
//                 panel, its place, corners, hairlines, seam, the module)
Scope {
    id: root

    // Bar.qml instances, one per screen, empty in island mode.
    property var bars: []

    function target() {
        const list = (root.bars || []).filter(b => b);
        const focused = Hyprland.focusedMonitor?.name ?? "";
        return list.find(b => b.screen?.name === focused) ?? list[0] ?? null;
    }

    function unavailable(): string {
        if (Prefs.barMode === "island")
            return "error: the bar is in island mode; `qs ipc call island open STATE` opens the island's panels";
        return root.target() ? "" : "error: no bar window yet";
    }

    IpcHandler {
        target: "bar"

        function open(state: string): string {
            const why = root.unavailable();
            return why !== "" ? why : root.target().host.open(state);
        }

        function close(): string {
            const why = root.unavailable();
            if (why !== "") return why;
            root.target().host.close();
            return "ok";
        }

        function toggle(state: string): string {
            const why = root.unavailable();
            return why !== "" ? why : root.target().host.toggle(state);
        }

        function inspect(): string {
            return JSON.stringify({
                mode: Prefs.barMode,
                edge: Prefs.edge,
                storedEdge: Prefs.storedEdge,
                reserve: Theme.barExtent,
                bars: (root.bars || []).filter(b => b).map(b => b.host.inspect())
            });
        }
    }
}
