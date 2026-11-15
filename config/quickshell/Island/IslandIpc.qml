import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs

// IslandIpc.qml - `qs ipc call island ...` (PLAN 1.8).
//
// Lives in shell.qml in every bar mode, so `island mode island` works from the
// pill too. The other verbs act on the island of the focused monitor (the
// first one when Hyprland cannot say) and answer "error: ..." outside island
// mode.
//
//   open STATE    rest | hover | crew | hail | vibes | cal | notif | osd | dict | flash | cc | launcher;
//                 cc opens the old Hud home under the rest pill and launcher
//                 opens Keystroke's own window until their island states land
//                 (PLAN 1.7). IPC has no input serial for a popup grab, so the
//                 Hud opens without one and the island's focus grab closes it
//                 on an outside click (IslandView.hudNeedsGrab). M2 adds crew
//                 (the Crew panel, pinned), hail (the first agent that needs
//                 you; an error when none does) and vibes. M3 adds cal (the
//                 calendar, a panel), notif (the newest waiting notification,
//                 or a fixture's `notif`; an error when there is none), osd
//                 and flash (each with its own 1400 ms), and dict (an error
//                 unless dictation is running)
//   close         back to rest, closing any hand-off
//   toggle STATE  open, or close when that state is already showing
//   hold          stop the state's timer, so an OSD, flash or notification
//                 stays up (sandbox shots); the next change starts afresh
//   mode MODE     pill | full | rail | island (Prefs.setBarMode)
//   inspect       JSON: mode, edges, the reserve and every island's state,
//                 target and current geometry
Scope {
    id: root

    // Island.qml instances, one per screen, empty outside island mode.
    property var islands: []
    // shell.qml's Launcher, for `open launcher` until M5.
    property var launcher: null

    function target() {
        const list = (root.islands || []).filter(i => i);
        const focused = Hyprland.focusedMonitor?.name ?? "";
        return list.find(i => i.screen?.name === focused) ?? list[0] ?? null;
    }

    function unavailable(): string {
        if (Prefs.barMode !== "island")
            return "error: the bar is in " + Prefs.barMode + " mode; `qs ipc call island mode island` shows the island";
        return root.target() ? "" : "error: no island window yet";
    }

    IpcHandler {
        target: "island"

        function open(state: string): string {
            const why = root.unavailable();
            if (why !== "") return why;
            if (state === "launcher") {
                if (!root.launcher) return "error: no launcher";
                root.target().view.close();
                root.launcher.open();
                return "ok";
            }
            return root.target().view.open(state);
        }

        function close(): string {
            const why = root.unavailable();
            if (why !== "") return why;
            if (root.launcher?.opened) root.launcher.close();
            return root.target().view.close();
        }

        function toggle(state: string): string {
            const why = root.unavailable();
            if (why !== "") return why;
            if (state === "launcher") {
                if (!root.launcher) return "error: no launcher";
                root.launcher.toggle();
                return "ok";
            }
            return root.target().view.toggle(state);
        }

        function hold(): string {
            const why = root.unavailable();
            if (why !== "") return why;
            return root.target().view.hold();
        }

        function mode(barMode: string): string {
            if (!Prefs.barModes.includes(barMode))
                return "error: unknown bar mode \"" + barMode + "\" (modes: " + Prefs.barModes.join(" ") + ")";
            Prefs.setBarMode(barMode);
            return "ok";
        }

        function inspect(): string {
            return JSON.stringify({
                mode: Prefs.barMode,
                edge: Prefs.edge,
                storedEdge: Prefs.storedEdge,
                reserve: Theme.barExtent,
                islands: (root.islands || []).filter(i => i).map(i => i.view.inspect())
            });
        }
    }
}
