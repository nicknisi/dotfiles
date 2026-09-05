// shell.qml - entry point. Quickshell loads this file and nothing else directly;
// the other .qml files in this directory are picked up by name.
//
// Run it with `qs`. Files are watched, so saving any of them reloads the shell in
// place. Backup of the original single-file bar is in shell.qml.bak.
import Quickshell
import Quickshell.Io

ShellRoot {
    // `qs ipc call theme reload`: bin/theme calls this after writing colors.json,
    // in case the file watch in Theme.qml missed the change (it can, when the
    // file did not exist when the shell started).
    IpcHandler {
        target: "theme"
        function reload(): void { Theme.reload() }
    }

    // One bar per connected monitor, created and destroyed as displays come and go.
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Both of these are global rather than per-monitor: one D-Bus notification
    // server for the session, one OSD.
    Notifications {}
    Osd {}
    ThemePicker {}

    // Refresh rate follows the charger. Global, not per-monitor: it drives the
    // internal panel only, and one UPower watcher is enough for the session.
    PowerMode {}
}
