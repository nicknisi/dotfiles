// ThemePicker.qml - the theme and wallpaper pickers' host (PLAN M7,
// launcher-pickers 7). Opened over IPC, which is what `theme picker
// [themes|backgrounds]` does (and the "Theme" / "Wallpaper" desktop entries,
// the launcher's Wallpaper Picker and the control center's Theme mini):
//     qs ipc call picker open themes
//
// The view is Panels/ThemesPanel.qml and Panels/WallpapersPanel.qml over
// Panels/PickerModel.qml (state and keys); this picks where they show each
// time the picker opens, as Launcher.qml does for the palette:
//
//   island mode   the island on the target screen becomes them: its `themes`
//                 and `wallpapers` states (1240 x 600, 780 x 252 or 444),
//                 morphing between the two on Tab. Leaving those states any
//                 other way (an outside click on the island's focus grab,
//                 `island close`, the palette opening) closes the picker.
//   pill, full,   a free panel: a full-screen transparent overlay (an outside
//   rail          click closes) with the content top centre, 8 under the
//                 bar's reserved zone (PLAN 1.6), on the island material,
//                 opaque, radius 28, the one shadow. It grows from its top
//                 edge on the spatial spring, fades in over effects, and
//                 follows the content's size on the spring when Tab switches.
//   fullscreen    in island mode, over a fullscreen window: the free panel
//                 where the island would put it (y 8); the island's Top layer
//                 is under the window (Launcher.qml's islandFor).
//
// Live preview (7.4): while a theme card other than the applied one has
// focus, Tokens.previewPalette is that pack's palette (`theme _rows` carries
// it), so everything drawn from Tokens (the island, these panels, the
// launcher) retints on the effects spring. Nothing is written until Enter.
// Esc, an outside click or Tab to the wallpapers fades back. Enter runs
// `theme <name>` (Panels/PickerRun.qml) and keeps the preview pinned to the
// chosen pack until colors.json names it (Theme.name), or 15 s pass, so the
// island does not flash back to the old theme in between. Windows,
// terminals and the wallpaper change only once bin/theme has run. A run that
// fails drops the pin at once and says so in a notification, with the last
// lines bin/theme printed (launcher-pickers 7.4).
//
// Rows come from `theme _rows <kind>` as JSON, reloaded on every open (the
// last rows stay on screen meanwhile), and the other kind's on the first Tab.
// Images are the thumbnails `theme thumbs` caches under ~/.cache/theme/thumbs,
// or the originals until that has run once. In the screenshot sandbox a
// fixture's `picker: { themes, backgrounds }` stands in, and under
// Fixture.dryRun nothing runs bin/theme (lastRun records what would have).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import qs
import qs.Kit
import qs.Panels

Scope {
    id: root

    // ~/.config/quickshell is a symlink into the dotfiles checkout; .. walks the
    // real parent, so this lands on dotfiles/bin/theme without hard-coding it.
    readonly property string themeBin: Quickshell.shellDir + "/../../bin/theme"

    // Island.qml instances (shell.qml), one per screen; empty outside island mode.
    property var islands: []
    // The island showing the picker, or null while the free panel does
    // (Panels/PickerRouter.qml). Chosen on every open, kept through the close.
    readonly property var shownIsland: router.shownIsland
    readonly property bool islandHosting: router.islandHosting
    property var targetScreen: null

    readonly property alias model: picker
    readonly property bool opened: picker.opened
    readonly property string kind: picker.kind

    // What the last Enter ran (or, under a dry run, would have): "hackerman",
    // "bg /path/to/image". For inspect() and the sandbox.
    property string lastRun: ""
    // The kinds whose rows have been asked for since this open.
    property var asked: ({})

    PickerModel {
        id: picker
        onApplied: (row, kind) => root.apply(row, kind)
        onCloseRequested: root.close()
    }

    // The live preview, and the pin that holds an applied theme until
    // colors.json names it (Panels/PickerPreview.qml).
    PickerPreview {
        id: preview
        model: picker
    }

    // Which island shows the picker, and the close when one leaves it.
    PickerRouter {
        id: router
        model: picker
    }

    // Enter's bin/theme runs, and what a failed one says.
    PickerRun {
        id: runs
        onEnded: (argv, code, output) => root.runEnded(argv, code, output)
    }

    // ---- opening and closing ---------------------------------------------------------
    function targetScreenNow() {
        const screens = Quickshell.screens;
        const active = Hyprland.activeToplevel;
        const monitors = [active ? active.monitor : null, Hyprland.focusedMonitor];
        for (const monitor of monitors) {
            if (!monitor || !monitor.name) continue;
            for (const screen of screens) {
                if (screen.name === monitor.name && screen.width > 0 && screen.height > 0) return screen;
            }
        }
        return screens.length ? screens[0] : null;
    }
    function kindOf(k: string): string {
        return k === "backgrounds" || k === "wallpapers" ? "backgrounds" : "themes";
    }
    function open(kind: string) {
        root.openOn(null, kind);
    }
    // The picker on `screen` (the focused one when null): the island's
    // `island open themes` and the control center's Theme mini.
    function openOn(screen, kind: string) {
        root.targetScreen = screen || root.targetScreenNow();
        root.asked = ({});
        picker.open(root.kindOf(kind));
        root.load(picker.kind);
        root.place();
    }
    function close() {
        if (!picker.opened) return;
        picker.close();
    }
    function toggle(kind: string) {
        if (picker.opened) root.close();
        else root.open(kind);
    }

    function load(kind: string) {
        if (root.asked[kind]) return;
        root.asked = Object.assign({}, root.asked, { [kind]: true });
        const fixture = Fixture.data.picker;
        if (fixture && Array.isArray(fixture[kind])) {
            picker.setRows(kind, fixture[kind]);
            return;
        }
        const proc = kind === "backgrounds" ? wallsProc : themesProc;
        proc.running = false;
        proc.running = true;
    }
    function accept(kind: string, text: string) {
        let parsed = [];
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            console.log("picker: bad rows: " + e);
        }
        picker.setRows(kind, Array.isArray(parsed) ? parsed : []);
    }
    Process {
        id: themesProc
        command: [root.themeBin, "_rows", "themes"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.accept("themes", text)
        }
    }
    Process {
        id: wallsProc
        command: [root.themeBin, "_rows", "backgrounds"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.accept("backgrounds", text)
        }
    }

    function apply(row, kind: string) {
        const argv = kind === "backgrounds" ? [root.themeBin, "bg", row.name] : [root.themeBin, row.name];
        root.lastRun = argv.slice(1).join(" ");
        if (kind === "themes") preview.pin(row);
        if (!Fixture.dryRun) runs.run(argv);
        root.close();
    }
    // A run ended. A failure unpins its theme (the shell goes back to the
    // applied one) and posts what bin/theme printed last, its error line
    // first, as a banner shows one line of the body.
    function runEnded(argv, code: int, output: string) {
        if (code === 0) return;
        const what = argv.slice(1).join(" ");
        const lines = output.split("\n").filter(l => l.trim() !== "");
        console.warn("picker: theme " + what + " exited " + code + (output ? ": " + lines.join(" | ") : ""));
        if (argv[1] !== "bg" && preview.pinnedName === argv[1]) preview.unpin();
        const body = (lines.length ? lines[lines.length - 1] + "\n" : "") + "theme " + what + " exited " + code;
        Quickshell.execDetached(["notify-send", "--app-name=Theme", "--", argv[1] === "bg" ? "Wallpaper not set" : "Theme not applied", body]);
    }

    // ---- the hosts -------------------------------------------------------------------
    // The island on `screen`, or null for the free panel: outside island mode,
    // and over a fullscreen window (Launcher.qml's rule and its reason).
    function fullscreenOn(screen) {
        const monitor = screen ? Hyprland.monitorFor(screen) : null;
        const workspace = monitor ? monitor.activeWorkspace : null;
        return !!workspace && workspace.hasFullscreen === true;
    }
    function islandFor(screen) {
        if (Prefs.barMode !== "island" || !screen || root.fullscreenOn(screen)) return null;
        return (root.islands || []).find(i => i && i.screen && i.screen.name === screen.name) ?? null;
    }
    function place() {
        router.place(picker.opened ? root.islandFor(root.targetScreen) : null);
    }
    Connections {
        target: picker
        function onOpenedChanged() {
            root.place();
        }
        // Tab: the other kind's rows on first use, and the island morphs to it.
        function onKindChanged() {
            if (!picker.opened) return;
            root.load(picker.kind);
            root.place();
            card.focusContent();
        }
    }
    // An island leaving its picker state without the picker closing it
    // closes the picker (PickerRouter's pickerLeft). A mode change while
    // open: the island went (the free panel carries on) or came (it takes
    // the picker over).
    onIslandsChanged: {
        router.forget(root.islands);
        if (picker.opened) Qt.callLater(root.place);
    }
    // The free panel took over an open picker: it grows in as on an open.
    onIslandHostingChanged: if (!root.islandHosting && picker.opened) panelIn.restart()

    // ---- the free panel (pill, full, rail; island mode over a fullscreen window) ----
    property bool panelClosing: false
    Connections {
        target: picker
        function onOpenedChanged() {
            panelOut.stop();
            if (picker.opened) {
                root.panelClosing = false;
                if (!root.islandHosting) panelIn.restart();
            } else {
                root.panelClosing = !root.islandHosting;
                if (root.panelClosing) panelOut.restart();
            }
        }
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
        visible: !root.islandHosting && (picker.opened || root.panelClosing)
        screen: root.targetScreen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "theme-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        // The keyboard goes back the moment it closes, however long the fade runs.
        WlrLayershell.keyboardFocus: picker.opened && !root.islandHosting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            width: picker.opened ? panel.width : 0
            height: picker.opened ? panel.height : 0
        }
        onVisibleChanged: if (visible) card.focusContent()

        MouseArea {
            objectName: "picker-dismiss-area"
            anchors.fill: parent
            onClicked: root.close()
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
            readonly property real dpr: panel.devicePixelRatio > 0 ? panel.devicePixelRatio : 1
            // Top centre, 8 under the bar's reserved zone when the bar is on
            // the top edge, else 8 under the screen's top; in island mode (a
            // fullscreen window) where the island would be, y 8.
            readonly property real topY: Prefs.barMode !== "island" && Prefs.edge === "top" ? Theme.barExtent + 8 : 8
            readonly property Item content: (picker.themes ? themesLoader.item : wallsLoader.item) ?? null
            readonly property real targetWidth: Math.min(content ? content.implicitWidth : (picker.themes ? 1240 : 780), panel.width - 2 * gaps)
            readonly property real targetHeight: Math.min(content ? content.implicitHeight : (picker.themes ? 600 : 444), panel.height - topY - gaps)
            // Follows the content on the spring once it is up (Tab between the two).
            property bool settled: false
            property real shownWidth: targetWidth
            property real shownHeight: targetHeight
            Behavior on shownWidth {
                enabled: card.settled
                NumberAnimation {
                    duration: Motion.spatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spring
                }
            }
            Behavior on shownHeight {
                enabled: card.settled
                NumberAnimation {
                    duration: Motion.spatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spring
                }
            }
            // 0 -> 1 as it opens: from the 64 px header down to its height.
            property real grow: 1
            width: Math.round(shownWidth * dpr) / dpr
            height: Math.round((Math.min(64, shownHeight) + (shownHeight - Math.min(64, shownHeight)) * grow) * dpr) / dpr
            x: Math.round((panel.width - width) / 2 * dpr) / dpr
            y: Math.round(topY * dpr) / dpr
            opacity: 0
            radius: 28
            color: Tokens.surface
            border.width: 1
            border.color: Tokens.hairline
            contentUnderBorder: true
            Accessible.role: Accessible.Dialog
            Accessible.name: picker.themes ? "Theme picker" : "Wallpaper picker"

            function focusContent() {
                Qt.callLater(() => {
                    if (card.content && panel.visible) card.content.forceActiveFocus();
                });
            }
            Connections {
                target: panel
                function onVisibleChanged() {
                    card.settled = false;
                    if (panel.visible) Qt.callLater(() => card.settled = panel.visible);
                }
            }

            // Clicks on the card stay on it.
            MouseArea {
                anchors.fill: parent
            }

            Layer {
                id: themesLayer
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: themesLoader.item ? themesLoader.item.implicitWidth : 1240
                height: themesLoader.item ? themesLoader.item.implicitHeight : 600
                current: picker.opened && picker.themes && !root.islandHosting
                Loader {
                    id: themesLoader
                    anchors.fill: parent
                    active: themesLayer.current || themesLayer.visible
                    sourceComponent: ThemesPanel {
                        picker: root.model
                        active: themesLayer.current
                        dpr: card.dpr
                        availableWidth: panel.width
                    }
                    onLoaded: card.focusContent()
                }
            }
            Layer {
                id: wallsLayer
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: 780
                height: wallsLoader.item ? wallsLoader.item.implicitHeight : 444
                current: picker.opened && !picker.themes && !root.islandHosting
                Loader {
                    id: wallsLoader
                    anchors.fill: parent
                    active: wallsLayer.current || wallsLayer.visible
                    sourceComponent: WallpapersPanel {
                        picker: root.model
                        active: wallsLayer.current
                        dpr: card.dpr
                    }
                    onLoaded: card.focusContent()
                }
            }
        }
    }

    // Item -> { x, y, width, height } in its window, or null when hidden.
    function box(item) {
        if (!item || !item.visible) return null;
        const p = item.mapToItem(null, 0, 0);
        return { x: Math.round(p.x * 100) / 100, y: Math.round(p.y * 100) / 100, width: item.width, height: item.height };
    }

    function inspect() {
        const content = card.content;
        return {
            opened: picker.opened,
            kind: picker.kind,
            host: !picker.opened ? "" : root.islandHosting ? "island" : "panel",
            screen: root.targetScreen?.name ?? "",
            loaded: picker.loaded,
            rows: picker.rows.length,
            matches: picker.matchCount,
            index: picker.index,
            focused: picker.focused?.name ?? "",
            filter: picker.filter,
            columns: picker.columns,
            preview: Tokens.previewPalette?.name ?? "",
            pinned: preview.pinnedName,
            lastRun: root.lastRun,
            dryRun: Fixture.dryRun,
            surface: Tokens.hex(Tokens.surface),
            // The free panel's card and its content's focus (the island's own
            // are in `island inspect`).
            panel: root.islandHosting ? null : root.box(card),
            panelFocus: !root.islandHosting && !!content && content.activeFocus
        };
    }

    IpcHandler {
        target: "picker"
        function open(kind: string): void {
            root.open(kind);
        }
        function close(): void {
            root.close();
        }
        function toggle(kind: string): void {
            root.toggle(kind);
        }
        // Focus a card by name (a theme's slug, a wallpaper's file name), as
        // the arrow keys or the pointer would: a theme previews.
        function select(name: string): string {
            if (!picker.opened) return "error: the picker is closed";
            return picker.focusName(name) ? "ok" : "error: no card named \"" + name + "\" in " + picker.kind;
        }
        function inspect(): string {
            return JSON.stringify(root.inspect());
        }
    }
}
