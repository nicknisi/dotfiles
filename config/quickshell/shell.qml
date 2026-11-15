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
import qs.Island

ShellRoot {
    id: root

    // `qs ipc call theme reload`: bin/theme calls this after writing colors.json,
    // in case the file watch in Theme.qml missed the change (it can, when the
    // file did not exist when the shell started).
    IpcHandler {
        target: "theme"
        function reload(): void { Theme.reload() }
    }

    // Per connected monitor, created and destroyed as displays come and go:
    // the classic bar (pill, full, rail) or the island, whichever
    // Prefs.barMode names, and beside it the 1px window that holds the
    // exclusive zone in every mode (see Reserve.qml for why that is not the
    // bar's own job). Only one of the two loaders is active, so a mode change
    // destroys one window and builds the other.
    Variants {
        id: screens
        model: Quickshell.screens
        delegate: Scope {
            id: screenScope
            required property var modelData
            readonly property var reserve: reserveWindow
            readonly property var island: islandLoader.item

            LazyLoader {
                active: Prefs.barMode !== "island"
                Bar {
                    modelData: screenScope.modelData
                }
            }
            LazyLoader {
                id: islandLoader
                active: Prefs.barMode === "island"
                Island {
                    modelData: screenScope.modelData
                }
            }
            Reserve {
                id: reserveWindow
                modelData: screenScope.modelData
            }
        }
    }

    // Mode-independent services: the tray watcher, Caffeine's idle inhibitor
    // (bound to a Reserve window, which exists in every bar mode) and the
    // refresh-rate policy, plus the guards that keep a SHELL_SANDBOX=1 run from
    // touching the real machine. See ShellServices.qml.
    ShellServices {
        reserves: screens.instances.map(s => s.reserve)
    }

    // `qs ipc call island ...`: open, close, toggle, mode, inspect. Present in
    // every mode so `island mode island` can leave the pill.
    IslandIpc {
        islands: screens.instances.map(s => s.island).filter(i => i)
        launcher: launcher
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
