import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Kit
import "WindowSwitcherModel.js" as Model

// WindowSwitcher.qml - Super+Tab's window thumbnails. Restyled to the island
// tokens in M5 (launcher-pickers 5.5); keys, GlobalShortcuts and IPC as before.
Scope {
    id: root

    property bool opened: false
    property var targetScreen: null
    property var entries: []
    property int selected: -1
    readonly property var current: entries[selected] || null
    // shell.qml's ScreenCorners: the scrim covers the whole screen on
    // Overlay, so the panel paints the corners over it (corners.drawn).
    property var corners: null

    function windows() {
        const rows = [];
        for (const t of ToplevelManager.toplevels.values) {
            let h = null;
            for (const candidate of Hyprland.toplevels.values) {
                if (candidate.wayland === t) { h = candidate; break; }
            }
            // Without a Hyprland identity, the mapping is still arriving.
            if (!h) continue;
            const app = DesktopEntries.heuristicLookup(t.appId);
            rows.push({ id: h.address, toplevel: t, active: t.activated,
                recency: typeof h.lastIpcObject.focusHistoryID === "number" ? h.lastIpcObject.focusHistoryID : 1000,
                title: t.title || t.appId || "Window", app: app ? app.name : t.appId,
                icon: app && app.icon ? Quickshell.iconPath(app.icon, true) : "",
                workspace: h.workspace ? h.workspace.name : "" });
        }
        return rows;
    }

    function step(delta) {
        if (!opened) {
            const monitor = Hyprland.focusedMonitor;
            targetScreen = Quickshell.screens.find(s => monitor && s.name === monitor.name) || Quickshell.screens[0] || null;
            entries = Model.snapshot(windows());
            if (!targetScreen || !entries.length) return;
            // Start on the previous window, not the one underneath the overlay.
            selected = entries[0].active ? 0 : (delta > 0 ? -1 : 0);
            opened = true;
        }
        selected = Model.cycle(selected, delta, entries.length);
        Qt.callLater(() => { keys.forceActiveFocus(); cards.positionViewAtIndex(selected, ListView.Contain); });
    }

    function cancel() {
        opened = false;
        entries = [];
        selected = -1;
    }

    function commit() {
        if (!opened) return;
        const target = current ? current.toplevel : null;
        cancel();
        // Drop the layer's keyboard grab before asking the compositor to focus.
        Qt.callLater(() => {
            if (target && ToplevelManager.toplevels.values.indexOf(target) !== -1) target.activate();
        });
    }

    function prune() {
        if (!opened) return;
        const next = Model.surviving(entries, windows().map(w => w.id), selected);
        entries = next.rows;
        selected = next.selected;
        if (!entries.length) cancel();
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root.prune(); }
    }

    // Native compositor signals keep rapid press/release events in order;
    // spawning a qs process for each keystroke could race opening with commit.
    GlobalShortcut {
        appid: "quickshell"
        name: "window-switcher-next"
        description: "Next window thumbnail"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "window-switcher-previous"
        description: "Previous window thumbnail"
        onPressed: root.step(-1)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "window-switcher-commit"
        description: "Activate selected window"
        onPressed: root.commit()
        onReleased: root.commit()
    }

    IpcHandler {
        target: "windowSwitcher"
        function step(delta: int): void { root.step(delta); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.cancel(); }
        function inspect(): string {
            const previews = [];
            for (let i = 0; i < cards.count; i++) {
                const item = cards.itemAtIndex(i);
                if (item) previews.push({ id: item.modelData.id, hasContent: item.hasPreview });
            }
            return JSON.stringify({ opened: root.opened, selected: root.selected,
                ids: root.entries.map(w => w.id), titles: root.entries.map(w => w.title), previews: previews,
                corners: switcherCorners.visible ? switcherCorners.radius : 0 });
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        screen: root.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "window-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // The scrim (main-tokens: rgba(bg, .56)); a click outside cancels.
        Rectangle {
            anchors.fill: parent
            color: Tokens.scrim
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: root.opened
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) root.cancel();
                else if (event.key === Qt.Key_Tab) root.step(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) root.step(-1);
                else if (event.key === Qt.Key_Right) root.step(1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commit();
                event.accepted = true;
            }
            Keys.onReleased: event => {
                if ((event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) && !event.isAutoRepeat)
                    root.commit();
                event.accepted = true;
            }

            // The island material (M5 token restyle): opaque surface, hairline
            // ring, the one shadow, radius 28. Cards are raised, radius 14;
            // the current one sits on accentTint with an accent ring.
            // Centred on whole device pixels: at scale 1.5 a centre on an odd
            // logical px (1200 - 270 = 930, so y 465) puts the 1 px ring
            // across two device rows.
            Surface {
                id: surface
                readonly property real dpr: panel.devicePixelRatio > 0 ? panel.devicePixelRatio : 1
                x: Math.round((parent.width - width) / 2 * dpr) / dpr
                y: Math.round((parent.height - height) / 2 * dpr) / dpr
                width: Math.min(parent.width - 48, Math.max(300, root.entries.length * 260 + 36))
                height: 270
                radius: 28

                Text {
                    x: 22; y: 18
                    text: "Windows"
                    color: Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 22; y: 20
                    text: (root.selected + 1) + " / " + root.entries.length
                    color: Tokens.inkDim
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }

                ListView {
                    id: cards
                    x: 18; y: 48
                    width: parent.width - 36; height: 174
                    orientation: ListView.Horizontal
                    spacing: 10
                    clip: true
                    cacheBuffer: 0
                    model: root.entries
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Motion.effects

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool hasPreview: preview.hasContent
                        width: Math.min(250, cards.width); height: cards.height
                        radius: 14
                        color: ListView.isCurrentItem ? Tokens.accentTint : Tokens.raised
                        border.width: 1
                        border.color: ListView.isCurrentItem ? Tokens.accent : Tokens.hairline

                        Rectangle {
                            id: imageArea
                            x: 7; y: 7; width: parent.width - 14; height: 119
                            radius: 8
                            color: Tokens.fillLow
                            clip: true

                            ScreencopyView {
                                id: preview
                                anchors.fill: parent
                                captureSource: root.opened ? card.modelData.toplevel : null
                                live: root.opened && card.x + card.width >= cards.contentX && card.x <= cards.contentX + cards.width
                                paintCursor: false
                                constraintSize: Qt.size(width * 2, height * 2)
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                source: card.modelData.icon
                                visible: !preview.hasContent && status === Image.Ready
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !preview.hasContent && !card.modelData.icon
                                name: "window"
                                size: 28
                                color: Tokens.inkDim
                            }
                        }
                        Text {
                            x: 11; y: 133; width: parent.width - 22
                            text: card.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Tokens.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Text {
                            x: 11; y: 151; width: parent.width - 22
                            text: card.modelData.app + (card.modelData.workspace ? " · " + card.modelData.workspace : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Tokens.inkDim
                            font.family: "Adwaita Sans"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.selected = card.index; root.commit(); }
                        }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                    spacing: 6
                    Repeater {
                        model: [["Tab", "cycle"], ["Shift", "reverse"], ["Super", "release to switch"], ["Esc", "cancel"]]
                        Row {
                            required property var modelData
                            required property int index
                            spacing: 6
                            Item { visible: parent.index > 0; width: 8; height: 1 }
                            Keycap { anchors.verticalCenter: parent.verticalCenter; small: true; fontSize: 10; text: parent.modelData[0] }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[1]
                                color: Tokens.inkDim
                                font.family: "Adwaita Sans"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }

        // Over the scrim and the card: the rounded screen corners
        // (ScreenCorners.drawn), which the scrim would otherwise grey.
        ScreenCornerSet {
            id: switcherCorners
            anchors.fill: parent
            radius: root.corners?.drawn ?? 0
        }
    }
}
