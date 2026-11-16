import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import "launcher"
import "launcher/ui" as LauncherUi
import "lib/Anchored.js" as Anchored

// Launcher.qml - the palette's host (PLAN M5).
//
// launcher/Keystroke.qml is the engine (providers, matching, voice, hotkeys,
// the IPC's state); launcher/ui/LauncherContent.qml is its view. This picks
// where the view shows each time the palette opens:
//
//   island mode   the island on the target screen becomes it: its `launcher`
//                 state, morphing to the content's size (760 x 472, a picker
//                 its own). Leaving that state any other way (an outside click
//                 on the island's focus grab, `island close`) closes the
//                 palette.
//   pill, full,   the free panel below: a full-screen transparent overlay
//   rail          (an outside click closes) with the content top centre, 8
//                 under the bar's reserved zone when the bar is on the top
//                 (PLAN 1.6; lib/Anchored.js free(): y 64 under the pill, 48
//                 under the full strip), else 8 under the screen's top; on
//                 the island material, opaque, radius 28, the one shadow. It grows from its top edge on the
//                 spatial spring and fades in over effects; a close fades it
//                 out over exitFade once the activated row's flash has
//                 peaked.
//   fullscreen    in island mode, over a fullscreen window: the free panel,
//                 where the island would put it (see islandFor).
//
// The palette and the control center (M6) hand the island to each other in
// place, with no stop at rest between: the control center's Clipboard opens
// the clipboard scope here (openScope, from IslandView), and an `island`
// effect (the System provider's Open Control center) moves the palette's
// island to that state before the palette closes (onIslandRequested). In the
// classic modes the same effect opens the bar's anchored panel (M4).
//
// Every IPC entry point is unchanged.
Scope {
    id: root
    readonly property alias opened: host.opened
    readonly property alias launcherHost: host
    // Island.qml instances (shell.qml), one per screen; empty outside island mode.
    property var islands: []
    // Bar.qml instances (shell.qml), one per screen; empty in island mode.
    property var classicBars: []
    // The island showing the palette, or null while the free panel does.
    // Chosen on every open, kept through the close.
    property var shownIsland: null
    readonly property bool islandHosting: shownIsland !== null
    readonly property var freePanel: panel

    function targetScreen() {
        const screens = Quickshell.screens
        const active = Hyprland.activeToplevel
        const monitors = [active ? active.monitor : null, Hyprland.focusedMonitor]
        for (const monitor of monitors) {
            if (!monitor || !monitor.name) continue
            for (const screen of screens) {
                if (screen.name === monitor.name && screen.width > 0 && screen.height > 0) return screen
            }
        }
        return screens.length ? screens[0] : null
    }
    function open() { host.targetScreen = targetScreen(); host.open("{}") }
    function close() { host.cancel() }
    function toggle() { host.opened ? host.close() : root.open() }
    function summon(payload) { host.targetScreen = targetScreen(); host.open(payload) }
    function route(route) { host.targetScreen = targetScreen(); host.openRoute(route, {}) }
    // The palette on `screen` (a ShellScreen; the focused one when null), in
    // `route` (clipboard, a provider scope) with openRoute's options.
    function openScope(screen, route, options) {
        host.targetScreen = screen || targetScreen()
        host.openRoute(route, options || {})
    }
    function query(query) { if (!host.opened) root.open(); return host.setQuery(query) }
    // A palette hotkey: run one provider row headlessly, `<provider>/<id>`.
    function run(route) { var result = host.run(route); return result ? String(result) : "unavailable" }

    // The island on `screen`, or null for the free panel: outside island mode,
    // and over a fullscreen window. The island's layer is Top, which Hyprland
    // draws under a fullscreen window, while its focus grab would still take
    // the keyboard; the free panel is on Overlay (M5 review). Changing the
    // island's layer at runtime remaps it and ends the grab, so the panel
    // hosts the palette there instead.
    function fullscreenOn(screen) {
        const monitor = screen ? Hyprland.monitorFor(screen) : null
        const workspace = monitor ? monitor.activeWorkspace : null
        return !!workspace && workspace.hasFullscreen === true
    }
    function islandFor(screen) {
        if (Prefs.barMode !== "island" || !screen || root.fullscreenOn(screen)) return null
        return (root.islands || []).find(i => i && i.screen && i.screen.name === screen.name) ?? null
    }
    function place() {
        if (host.opened) {
            const island = root.islandFor(host.targetScreen)
            if (root.shownIsland && root.shownIsland !== island) root.shownIsland.view.releaseLauncher(0)
            root.shownIsland = island
            host.hostKind = island ? "island" : "panel"
            if (island) island.view.showLauncher(host)
        } else if (root.shownIsland) {
            // Back to rest once the activated row's flash has peaked.
            root.shownIsland.view.releaseLauncher(Math.max(0, host.flashUntil - Date.now()))
        }
    }
    Connections {
        target: host
        function onOpenedChanged() { root.place() }
    }
    // The island left its launcher state without the palette closing it.
    Connections {
        target: root.shownIsland ? root.shownIsland.view : null
        ignoreUnknownSignals: true
        function onLauncherLeft() { if (host.opened) host.cancel() }
    }
    // An `island` effect: the palette's island (or, from a headless hotkey,
    // the focused screen's) shows that state, then the engine closes the
    // palette. The state change leaves the launcher state, which closes the
    // palette here first (onLauncherLeft), so the island morphs straight from
    // the palette to it. Nothing over a fullscreen window or outside island
    // mode (islandFor is null): the island would open under the window.
    Connections {
        target: host
        function onIslandRequested(state) {
            const screen = host.opened && host.targetScreen ? host.targetScreen : root.targetScreen()
            const island = root.shownIsland && root.shownIsland.view.launcherShown ? root.shownIsland
                : root.islandFor(screen)
            if (island) {
                island.view.open(state)
                return
            }
            // The classic modes: the bar's anchored host on that screen.
            const bars = (root.classicBars || []).filter(b => b)
            const bar = bars.find(b => screen && b.screen && b.screen.name === screen.name) ?? bars[0] ?? null
            if (bar) {
                // After the palette's close, so the host's focus grab is the
                // one left standing.
                Qt.callLater(() => bar.host.open(state))
                return
            }
            console.warn("launcher: no island or bar for `" + state + "` (a fullscreen window?)")
        }
    }
    // A mode change took the island away: the free panel carries on.
    onIslandsChanged: {
        if (root.shownIsland && (root.islands || []).indexOf(root.shownIsland) < 0) {
            root.shownIsland = null
            if (host.opened) host.hostKind = "panel"
        }
    }

    Keystroke { id: host }

    // The free panel's own reveal (see the header): it stays mapped while it
    // fades out, after the palette has closed.
    property bool panelClosing: false
    Connections {
        target: host
        function onOpenedChanged() {
            panelHide.stop();
            panelOut.stop();
            if (host.opened) {
                root.panelClosing = false;
                panelIn.restart();
            } else {
                root.panelClosing = true;
                panelHide.interval = Math.max(0, host.flashUntil - Date.now());
                panelHide.restart();
            }
        }
    }
    Timer {
        id: panelHide
        onTriggered: panelOut.restart()
    }
    ParallelAnimation {
        id: panelIn
        NumberAnimation {
            target: card
            property: "grow"
            from: 0
            to: 1
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    NumberAnimation {
        id: panelOut
        target: card
        property: "opacity"
        to: 0
        duration: Motion.exitFade
        onFinished: root.panelClosing = false
    }

    PanelWindow {
        id: panel
        visible: !root.islandHosting && (host.opened || root.panelClosing)
        screen: host.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        // A launch must find the keyboard free at once, however long the fade-out runs.
        WlrLayershell.keyboardFocus: host.opened && !root.islandHosting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { width: host.opened ? panel.width : 0; height: host.opened ? panel.height : 0 }

        MouseArea {
            objectName: "launcher-dismiss-area"
            anchors.fill: parent
            onClicked: host.cancel()
        }

        RectangularShadow {
            anchors.fill: card
            opacity: card.opacity
            radius: card.radius
            offset: Qt.vector2d(0, 10)
            blur: 28
            color: Tokens.shadow
        }
        ClippingRectangle {
            id: card
            readonly property int gaps: 16
            // On whole device pixels (scale 1.5: an odd logical offset splits
            // the 1 px ring across two device rows).
            readonly property real dpr: panel.devicePixelRatio > 0 ? panel.devicePixelRatio : 1
            // Top centre, 8 under the bar's reserved zone when the bar is on
            // the top edge (PLAN 1.6: y 64 under the pill, 48 under the full
            // strip), else 8 under the screen's top; in island mode (a
            // fullscreen window) where the island would be, y 8
            // (lib/Anchored.js free()).
            readonly property real topY: Anchored.free({
                mode: Prefs.barMode,
                edge: Prefs.edge,
                screen: { width: panel.width, height: panel.height },
                reserve: Theme.barExtent,
                size: { width: content.implicitWidth, height: content.implicitHeight },
                dpr: card.dpr
            }).y
            readonly property real fullHeight: Math.min(content.implicitHeight, panel.height - topY - gaps)
            // 0 -> 1 as it opens: from the 56 px header down to its height.
            property real grow: 1
            width: Math.min(content.implicitWidth, panel.width - 2 * gaps)
            height: Math.round((Math.min(56, fullHeight) + (fullHeight - Math.min(56, fullHeight)) * grow) * dpr) / dpr
            x: Math.round((panel.width - width) / 2 * dpr) / dpr
            y: Math.round(topY * dpr) / dpr
            opacity: 0
            radius: 28
            color: Tokens.surface
            border.width: 1
            border.color: Tokens.hairline
            contentUnderBorder: true
            Accessible.role: Accessible.Dialog
            Accessible.name: "Launcher command palette"
            // Clicks on the card stay on it.
            MouseArea { anchors.fill: parent }
            // At its own size from the card's top: the card's growing edge
            // clips it, the rows never reflow.
            LauncherUi.LauncherContent {
                id: content
                width: card.width
                height: card.fullHeight
                engine: host
                active: !root.islandHosting
            }
        }
    }

    // Super+Space and hold-to-talk (config/hypr/hyprland.lua and the
    // launcher-voice.lua block Keystroke Settings › Voice writes). The
    // compositor hands these over in order with no process per key, where
    // `qs ipc call launcher ...` started one (64 ms each on milhouse). A
    // non-release bind also delivers its release, which only the release
    // shortcut acts on. The IPC below keeps every verb for scripts.
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher-toggle"
        description: "Open or close the launcher"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher-voice-hold"
        description: "Dictate while the launcher hotkey is held"
        onPressed: host.voiceHold()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher-voice-release"
        description: "Stop dictating when the launcher hotkey is let go"
        onReleased: host.voiceRelease()
    }

    IpcHandler {
        target: "launcher"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function summon(payload: string): void { root.summon(payload) }
        function route(route: string): void { root.route(route) }
        function query(query: string): string { return root.query(query) }
        function run(route: string): string { return root.run(route) }
        function cancelPicker(doneFile: string): void { if (host.requestActive && host.doneFile === doneFile) host.cancel() }
        function inspect(): string { return host.inspect() }
        function inspectConversation(): string { return host.inspectConversation() }
        function voiceHold(): string { return host.voiceHold() }
        function voiceRelease(): string { return host.voiceRelease() }
        // The screenshot sandbox has no keyboard: Enter on the selected row,
        // so a shot can open what a row opens (the Codex view). Refused
        // outside SHELL_SANDBOX=1.
        function activate(): string {
            if (!Fixture.sandbox) return "error: activate is for the screenshot sandbox only"
            if (!host.opened) return "error: the launcher is closed"
            host.activate()
            return "ok"
        }
        // The same for a click on the detail card's Actions: its list opens.
        function actions(): string {
            if (!Fixture.sandbox) return "error: actions is for the screenshot sandbox only"
            if (!host.opened || !host.attachedView) return "error: the launcher is closed"
            return host.attachedView.openActions() ? "ok" : "error: the selected row has no other actions"
        }
    }
}
