// shell.qml - entry point. Quickshell loads this file and nothing else directly;
// the other .qml files in this directory are picked up by name.
//
// Run it with `qs`. Files are watched, so saving any of them reloads the shell in
// place. Backup of the original single-file bar is in shell.qml.bak.
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Awake is deliberately session-only: a shell restart restores normal idle
    // behavior instead of silently keeping the machine awake forever.
    property bool awake: false

    // `qs ipc call theme reload`: bin/theme calls this after writing colors.json,
    // in case the file watch in Theme.qml missed the change (it can, when the
    // file did not exist when the shell started).
    IpcHandler {
        target: "theme"
        function reload(): void { Theme.reload() }
    }

    // One capsule per connected monitor, created and destroyed as displays
    // come and go, and beside each one the 1px window that holds its exclusive
    // zone (see Reserve.qml for why that is not the capsule's own job).
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            awake: root.awake
            onAwakeToggled: root.awake = !root.awake
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Reserve {}
    }

    // Global rather than per-monitor: one D-Bus notification server for the
    // session. The OSD that used to live beside it is gone; volume, brightness
    // and the mic are messages the capsule delivers itself, through Interrupt.
    Notifications {}
    NotificationCenter {}
    ThemePicker {}
    Launcher {}
    ClipboardPicker {}

    // Refresh rate follows the charger. Global, not per-monitor: it drives the
    // internal panel only, and one UPower watcher is enough for the session.
    PowerMode {}
}
