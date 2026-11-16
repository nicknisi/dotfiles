import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs

// PanelShortcuts.qml - Super+Alt+C and Super+Alt+D (config/hypr/hyprland.lua):
// the control center and the calendar, as global shortcuts (appid
// "quickshell"), on the focused monitor.
//
//   island mode   the island's cc and cal states (IslandView.toggle), as
//                 `island toggle cc|cal` does. Over a fullscreen window the
//                 island is on the Top layer, under the window, where its
//                 focus grab would take the keys of a panel nobody can see:
//                 there it rises to Overlay first, as it does for the power
//                 menu, and goes back down when the panel closes
//                 (IslandView.toggleRaised; keys review).
//   pill, full,   the bar's anchored panel from the status module or the
//   rail          clock (AnchoredHost.toggle), as `bar toggle cc|cal` does.
//                 An open palette closes first, so the panel's focus grab is
//                 the one left standing (the palette's own hand-off,
//                 Launcher.qml onIslandRequested).
//
// A second press closes what the first opened. toggle() answers like the IPC
// ("ok" or "error: ..."), for tests/shortcuts.sh; the shortcuts only call it.
Scope {
    id: root

    // Island.qml instances, one per screen; empty outside island mode.
    property var islands: []
    // Bar.qml instances, one per screen; empty in island mode.
    property var bars: []
    // shell.qml's Launcher. Not named `launcher` (Island.qml's paletteHost
    // says why).
    property var paletteHost: null
    // The focused monitor's name; Hyprland's, unless a test sets it.
    property string focused: Hyprland.focusedMonitor?.name ?? ""
    // The monitors showing a fullscreen window, for tests/shortcuts.sh; null
    // asks Hyprland at the press.
    property var fullscreenNames: null

    function pick(list) {
        const shown = (list || []).filter(x => x);
        return shown.find(x => x.screen?.name === root.focused) ?? shown[0] ?? null;
    }
    function fullscreenOn(screen) {
        const name = screen?.name ?? "";
        if (root.fullscreenNames) return root.fullscreenNames.indexOf(name) >= 0;
        const monitor = Hyprland.monitors.values.find(m => m.name === name);
        return monitor?.activeWorkspace?.hasFullscreen === true;
    }

    function toggle(state: string): string {
        if (Prefs.barMode === "island") {
            const island = root.pick(root.islands);
            if (!island) return "error: no island window yet";
            if (root.fullscreenOn(island.screen)) return island.view.toggleRaised(state);
            return island.view.toggle(state);
        }
        const bar = root.pick(root.bars);
        if (!bar) return "error: no bar window yet";
        if (root.paletteHost?.opened) {
            root.paletteHost.close();
            Qt.callLater(() => bar.host.toggle(state));
            return "ok";
        }
        return bar.host.toggle(state);
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "control-center-toggle"
        description: "Open or close the control center"
        onPressed: root.toggle("cc")
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "calendar-toggle"
        description: "Open or close the calendar"
        onPressed: root.toggle("cal")
    }
}
