import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "launcher"

Scope {
    id: root
    readonly property alias opened: host.opened
    readonly property alias launcherHost: host

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
    function query(query) { if (!host.opened) root.open(); return host.setQuery(query) }

    Keystroke { id: host }

    IpcHandler {
        target: "launcher"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function summon(payload: string): void { root.summon(payload) }
        function route(route: string): void { root.route(route) }
        function query(query: string): string { return root.query(query) }
        function cancelPicker(doneFile: string): void { if (host.requestActive && host.doneFile === doneFile) host.cancel() }
        function inspect(): string { return host.inspect() }
        function inspectConversation(): string { return host.inspectConversation() }
        function voiceHold(): string { return host.voiceHold() }
        function voiceRelease(): string { return host.voiceRelease() }
    }
}
