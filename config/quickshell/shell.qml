// shell.qml - entry point. Quickshell loads this file and nothing else directly;
// the other .qml files in this directory are picked up by name.
//
// Run it with `qs`. Files are watched, so saving any of them reloads the shell in
// place. Backup of the original single-file bar is in shell.qml.bak.
import Quickshell

ShellRoot {
    // One bar per connected monitor, created and destroyed as displays come and go.
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Both of these are global rather than per-monitor: one D-Bus notification
    // server for the session, one OSD.
    Notifications {}
    Osd {}
}
