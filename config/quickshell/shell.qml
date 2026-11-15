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
                    // The island's own states (M3): banners from the one
                    // notification server, dictation from the launcher's voice.
                    notifications: notificationServer
                    voice: launcher.launcherHost.voice
                    // The palette and the control center hand the island to
                    // each other in place (IslandView, Launcher.qml).
                    paletteHost: launcher
                    // A polkit request (M8) shows on the screen that was
                    // focused when it started.
                    polkitFlow: services.polkitFlow
                    polkitHere: services.polkitScreen === "" || services.polkitScreen === screenScope.modelData.name
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
        id: services
        reserves: screens.instances.map(s => s.reserve)
    }
    // A polkit request in the classic bar modes (M8): the island draws it in
    // island mode. Built only while a flow exists (the agent, Prefs.polkitAgent,
    // off until the switch-over; a fixture in the sandbox), and kept while it
    // fades out.
    LazyLoader {
        id: polkitWindowLoader
        active: Prefs.barMode !== "island" && (services.polkitFlow !== null || (polkitWindowLoader.item?.showing ?? false))
        PolkitWindow {
            flow: services.polkitFlow
            screenName: services.polkitScreen
        }
    }

    // `qs ipc call island ...`: open, close, toggle, mode, inspect. Present in
    // every mode so `island mode island` can leave the pill.
    IslandIpc {
        islands: screens.instances.map(s => s.island).filter(i => i)
        launcher: launcher
    }

    // Global rather than per-monitor: one D-Bus notification server for the
    // session (NotificationServer.qml), whatever the bar mode. The classic
    // modes draw its toasts (Notifications.qml); the island draws banners.
    // The OSD that used to live beside it is gone; volume, brightness and the
    // mic are messages the bar or the island delivers itself, through Interrupt.
    NotificationServer {
        id: notificationServer
    }
    Notifications {
        source: notificationServer
    }
    NotificationCenter {}
    ThemePicker {}
    // The palette: the island's launcher state in island mode, its own panel
    // in the classic modes (Launcher.qml).
    Launcher {
        id: launcher
        islands: screens.instances.map(s => s.island).filter(i => i)
    }
    // Dictation from the daemon (the Copilot key): this bottom popup in the
    // classic modes, the island's dict state in island mode.
    VoxtypeOsd {
        voice: launcher.launcherHost.voice
        onVisibleChanged: if (visible) screen = launcher.targetScreen()
    }
    // Clipboard history capture (the wl-paste watchers) in every bar mode, and
    // the `clipboard` IPC that Super+V uses: the launcher's clipboard scope.
    ClipboardStore {
        launcher: launcher
    }
    WindowSwitcher {}
}
