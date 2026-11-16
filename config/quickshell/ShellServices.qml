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
//   - The `capture` IPC target (Capture), which no bar may be around to build,
//     and the `crew` target (Crew) for the same reason. Crew polls only in the
//     island mode, so building it elsewhere costs nothing.
//   - The refresh-rate policy (PowerMode).
//   - The night light (NightLight): built at startup in every mode, so the
//     stored state goes back on the screen when the shell starts and the
//     `nightlight` IPC target exists before anything draws its tile.
//   - Sandbox guards. Under SHELL_SANDBOX=1 (the screenshot sandbox) anything
//     that would change the real machine is left unbuilt.
//   - The polkit agent (PLAN M8): Quickshell's PolkitAgent, built only when
//     Prefs.polkitAgent is on and never in the sandbox (with the system bus
//     it would register for the real login session). The pref stays off
//     until the switch-over disables hyprpolkitagent: one agent owns a
//     session, and two would fight over registration. `polkitFlow` is the
//     request the island (or PolkitWindow in the classic modes) draws, and
//     `polkitScreen` the screen that was focused when it started. In the
//     sandbox a fixture's `polkit` object stands in for the flow
//     (Island/FixtureAuthFlow.qml), so shots never need the agent. The
//     `polkit` IPC target: inspect, and agent on|off (the pref).
//     Switch-over (not applied; after the merge, with a TTY logged in):
//       1. config/mise/config.toml: drop hyprpolkitagent.service from the
//          `systemctl --user enable` list (and the pacman package if wanted).
//       2. config/hypr/hyprland.lua:9: drop hyprpolkitagent from the enable
//          comment and name this file as the agent; it can leave the
//          windowrule's class list (line 272).
//       3. systemctl --user disable --now hyprpolkitagent;
//          qs ipc call polkit agent on; qs ipc call polkit inspect shows
//          registered: true; `pkexec true` shows the prompt.
//       Back out: qs ipc call polkit agent off; systemctl --user enable --now
//       hyprpolkitagent.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import Quickshell.Services.SystemTray
import QtQuick
import qs.Island

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
    // The same for `crew`: tests and the sandbox drive the Crew by IPC even
    // when the island has not read it yet.
    readonly property int crewTotal: Crew.total
    // And `nightlight`, which also re-applies the stored night light at start.
    readonly property bool nightLightActive: NightLight.active

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

    // ---- polkit (M8) -----------------------------------------------------------

    readonly property bool polkitEnabled: Prefs.polkitAgent && !root.sandbox
    readonly property var polkitAgent: polkitLoader.item
    readonly property var polkitFlow: root.fixtureFlow ?? root.polkitAgent?.flow ?? null
    property string polkitScreen: ""
    // The classic modes' PolkitWindow while it is built (shell.qml), for
    // `polkit inspect`.
    property var polkitWindow: null

    LazyLoader {
        id: polkitLoader
        active: root.polkitEnabled
        PolkitAgent {
            onAuthenticationRequestStarted: root.polkitScreen = String(Hyprland.focusedMonitor?.name ?? "")
        }
    }

    // A sandbox fixture's `polkit`: { message, actionId, inputPrompt, accept }.
    readonly property var fixturePolkit: root.sandbox ? (Fixture.data.polkit ?? null) : null
    property var fixtureFlow: null
    onFixturePolkitChanged: {
        const old = root.fixtureFlow;
        root.fixtureFlow = null;
        if (old) old.destroy();
        const f = root.fixturePolkit;
        if (!f) return;
        const props = {};
        for (const k of ["message", "actionId", "inputPrompt", "accept", "supplementaryMessage"]) {
            if (typeof f[k] === "string") props[k] = f[k];
        }
        if (f.supplementaryIsError === true) props.supplementaryIsError = true;
        if (f.failed === true) props.failed = true;
        root.polkitScreen = String(Hyprland.focusedMonitor?.name ?? "");
        root.fixtureFlow = fixtureFlowComponent.createObject(root, props);
    }
    Component {
        id: fixtureFlowComponent
        FixtureAuthFlow {}
    }

    IpcHandler {
        target: "polkit"
        function inspect(): string {
            return JSON.stringify({
                pref: Prefs.polkitAgent,
                sandbox: root.sandbox,
                built: root.polkitAgent !== null,
                registered: root.polkitAgent?.isRegistered ?? false,
                active: root.polkitAgent?.isActive ?? false,
                fixture: root.fixtureFlow !== null,
                screen: root.polkitScreen,
                actionId: String(root.polkitFlow?.actionId ?? ""),
                window: root.polkitWindow ? root.polkitWindow.inspect() : null
            });
        }
        // on | off: Prefs.polkitAgent. Turn it on only once hyprpolkitagent
        // is disabled (PLAN 3.5).
        function agent(state: string): string {
            if (state !== "on" && state !== "off") return "error: agent on|off";
            Prefs.setPolkitAgent(state === "on");
            return "ok";
        }
    }
}
