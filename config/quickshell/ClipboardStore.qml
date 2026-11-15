// ClipboardStore.qml - clipboard history capture, in every bar mode (PLAN M5).
//
// The wl-paste watchers that feed cliphist live here, apart from any view,
// so history keeps filling whatever the bar mode and whether or not anything
// is showing it. The history itself is the launcher's clipboard scope
// (launcher/providers/Clipboard.qml: Enter copies, Ctrl+Enter pastes); the
// old ClipboardPicker window is retired.
//
// The scope's Ctrl+Delete (or its "Ctrl Del Clear history" hint) asks the
// launcher to confirm, then wipes here, as the old picker's Ctrl+Delete did.
//
// `qs ipc call clipboard ...` keeps its verbs, so hyprland.lua's Super+V bind
// (toggle with the focused monitor's name) is unchanged:
//   open SCREEN    the launcher on that screen, in the clipboard scope
//   close          close it, when the clipboard scope is what is showing
//   toggle SCREEN  open, or close when the clipboard scope is showing
//   clear          wipe cliphist and the decoded media cache
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // shell.qml's Launcher.
    property var launcher: null
    readonly property var host: launcher ? launcher.launcherHost : null
    readonly property bool opened: !!host && host.opened && host.scope === "clipboard"

    readonly property string mediaCache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard-media"
    readonly property string mediaIndex: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/cliphist/media.tsv"

    IpcHandler {
        target: "clipboard"
        function open(screenName: string): void { root.open(screenName) }
        function close(): void { root.close() }
        function toggle(screenName: string): void { root.opened ? root.close() : root.open(screenName) }
        function clear(): void { root.clearHistory() }
    }

    // Separate MIME watchers ensure browsers' image data wins over text
    // fallbacks. They write the real cliphist history, so a screenshot
    // sandbox (SHELL_SANDBOX=1) never starts them. tests/clipboard-store.sh
    // runs them against fakes of wl-paste and cliphist.
    readonly property bool capturing: Quickshell.env("SHELL_SANDBOX") !== "1"
    readonly property alias watchers: watcherList
    QtObject {
        id: watcherList
        readonly property bool text: textWatch.running
        readonly property bool image: imageWatch.running
        readonly property bool video: videoWatch.running
    }
    Process {
        id: textWatch
        running: root.capturing
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && exec wl-paste --type text --watch cliphist store"]
    }
    Process {
        id: imageWatch
        running: root.capturing
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && exec wl-paste --type image --watch cliphist store"]
    }
    Process {
        id: videoWatch
        running: root.capturing
        command: ["sh", "-c", "command -v clipboard-store-video >/dev/null 2>&1 && exec wl-paste --type video --watch clipboard-store-video"]
    }

    Process {
        id: wipe
        command: [
            "sh", "-c", "cliphist wipe && rm -rf -- \"$1\" && rm -f -- \"$2\" \"$2.lock\"",
            "clipboard-history", root.mediaCache, root.mediaIndex
        ]
        // An open clipboard scope reloads (the provider lists on entering it),
        // so it shows the empty history at once.
        onExited: (code, status) => {
            if (code === 0 && root.opened) root.host.openRoute("clipboard", { title: "Clipboard History" })
        }
    }

    // Ctrl+Delete in the clipboard scope (or its footer hint), once confirmed.
    Connections {
        target: root.host
        ignoreUnknownSignals: true
        function onClipboardWipeConfirmed() { root.clearHistory() }
    }

    function screenFor(name): var {
        for (const screen of Quickshell.screens)
            if (screen.name === name) return screen;
        return null;
    }

    function open(screenName): void {
        if (!root.host) return;
        root.host.targetScreen = root.screenFor(screenName) ?? root.launcher.targetScreen();
        root.host.openRoute("clipboard", { title: "Clipboard History" });
    }

    function close(): void {
        if (root.opened) root.host.cancel();
    }

    function clearHistory(): void {
        if (!wipe.running) wipe.running = true;
    }
}
