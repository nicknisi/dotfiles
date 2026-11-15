// ShellServices.qml - the services every bar mode needs, owned by no bar.
//
// shell.qml builds one of these for the session. Anything here has to keep
// working whichever bar mode is showing, including when no Bar exists at all
// (the island mode builds an Island instead), so none of it may live inside a
// bar window.
//
//   - The tray watcher. Touching SystemTray at startup registers
//     org.kde.StatusNotifierWatcher on the session bus. 1Password's autostart
//     drop-in (After=quickshell.service) waits up to 10 s for that name, and
//     the island mode shows no tray icons, so nothing else would touch it early.
//   - Caffeine's idle inhibitor. Wayland ties an inhibitor to a surface, so it
//     rides the primary screen's Reserve window: the one window that exists in
//     every bar mode, for as long as the screen does.
//   - The `capture` IPC target (Capture), which no bar may be around to build.
//   - The refresh-rate policy (PowerMode).
//   - Sandbox guards. Under SHELL_SANDBOX=1 (the screenshot sandbox) anything
//     that would change the real machine is left unbuilt. M8 adds the
//     PolkitAgent here behind the same guard: in a sandbox with the system bus
//     it would register for the real login session.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick

Scope {
    id: root

    // The Reserve windows, one per screen: shell.qml passes its Variants'
    // instances.
    property list<QtObject> reserves

    readonly property bool sandbox: Fixture.sandbox

    // The Reserve on the first screen Quickshell lists; the first Reserve when
    // the screens are mid-change; null before any screen exists.
    readonly property var primaryReserve: {
        const first = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        let fallback = null;
        for (let i = 0; i < root.reserves.length; i++) {
            const reserve = root.reserves[i];
            if (!reserve) continue;
            if (reserve.screen === first) return reserve;
            if (!fallback) fallback = reserve;
        }
        return fallback;
    }

    // Read once at startup and kept bound, so the tray singleton (and with it
    // the watcher) exists from the first frame in every mode.
    readonly property int trayItemCount: SystemTray.items.values.length

    // A singleton is built on first use, and its IpcHandler with it. Today only
    // Bar reads Capture, so without this a mode with no Bar would drop the
    // `capture` target that bin/capture pings on every start and stop.
    readonly property bool captureRecording: Capture.recording

    IdleInhibitor {
        window: root.primaryReserve
        enabled: Caffeine.active && root.primaryReserve !== null
    }

    // Refresh rate follows the charger. Global, not per-monitor: it drives the
    // internal panel only, and one UPower watcher is enough for the session.
    // Not in the sandbox: panel-hz drives hyprctl and the real panel.
    LazyLoader {
        active: !root.sandbox
        PowerMode {}
    }
}
