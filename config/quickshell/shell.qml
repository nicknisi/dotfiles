// shell.qml - entry point. Quickshell loads this file and nothing else directly;
// the other .qml files in this directory are picked up by name.
//
// Run it with `qs`. Files are watched, so saving any of them reloads the shell in
// place.
//
// SHELL_SANDBOX=1 marks a screenshot sandbox run (.shell-rebuild/tmp/shoot.sh):
// ShellServices leaves out what would change the real machine, a few services
// skip their writers, and Fixture registers its `fixture` IPC target.
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

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
        delegate: Bar {}
    }
    Variants {
        id: reserveWindows
        model: Quickshell.screens
        delegate: Reserve {}
    }

    // Mode-independent services: the tray watcher, Caffeine's idle inhibitor
    // (bound to a Reserve window, which exists in every bar mode) and the
    // refresh-rate policy, plus the guards that keep a SHELL_SANDBOX=1 run from
    // touching the real machine. See ShellServices.qml.
    ShellServices {
        reserves: reserveWindows.instances
    }

    // Global rather than per-monitor: one D-Bus notification server for the
    // session. The OSD that used to live beside it is gone; volume, brightness
    // and the mic are messages the capsule delivers itself, through Interrupt.
    Notifications {}
    NotificationCenter {}
    ThemePicker {}
    Launcher { id: launcher }
    VoxtypeOsd {
        voice: launcher.launcherHost.voice
        onVisibleChanged: if (visible) screen = launcher.targetScreen()
    }
    ClipboardPicker {}
    WindowSwitcher {}
}
