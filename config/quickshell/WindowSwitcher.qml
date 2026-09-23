import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "WindowSwitcherModel.js" as Model

Scope {
    id: root

    property bool opened: false
    property var targetScreen: null
    property var entries: []
    property int selected: -1
    readonly property var current: entries[selected] || null

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
                ids: root.entries.map(w => w.id), titles: root.entries.map(w => w.title), previews: previews });
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

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.sunken, 0.30)
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

            ShellSurface {
                id: surface
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, Math.max(300, root.entries.length * 260 + 36))
                height: 270
                fill: Theme.alpha(Theme.surface, 0.97)

                Text {
                    x: 22; y: 17
                    text: "Windows"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 22; y: 19
                    text: (root.selected + 1) + " / " + root.entries.length
                    color: Theme.secondary
                    font.family: Theme.uiFont
                    font.pixelSize: 12
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
                    highlightMoveDuration: Theme.quick

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool hasPreview: preview.hasContent
                        width: Math.min(250, cards.width); height: cards.height
                        radius: Theme.controlRadius
                        color: ListView.isCurrentItem ? Theme.glowFill : Theme.raised
                        border.width: ListView.isCurrentItem ? 2 : 1
                        border.color: ListView.isCurrentItem ? Theme.accent : Theme.borderIdle

                        Rectangle {
                            id: imageArea
                            x: 7; y: 7; width: parent.width - 14; height: 119
                            radius: 7
                            color: Theme.sunken
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
                            Text {
                                anchors.centerIn: parent
                                visible: !preview.hasContent && !card.modelData.icon
                                text: "󰖯"
                                color: Theme.secondary
                                font.family: Theme.icons
                                font.pixelSize: 32
                            }
                        }
                        Text {
                            x: 11; y: 133; width: parent.width - 22
                            text: card.modelData.title
                            elide: Text.ElideRight
                            color: Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            x: 11; y: 150; width: parent.width - 22
                            text: card.modelData.app + (card.modelData.workspace ? " · " + card.modelData.workspace : "")
                            elide: Text.ElideRight
                            color: Theme.secondary
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.selected = card.index; root.commit(); }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 17
                    text: "Tab to cycle · Shift to reverse · Release Super to switch · Esc to cancel"
                    color: Theme.secondary
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
            }
        }
    }
}
