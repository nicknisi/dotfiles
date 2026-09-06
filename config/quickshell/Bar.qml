// One fixed-width capsule per monitor. Only the workspace pills stretch:
// the clock, status controls, and morphing endcap never move on hover.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData
    anchors { top: true }
    margins.top: 4
    exclusiveZone: Theme.barHeight
    implicitWidth: Math.min(400, screen.width - 16)
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell-capsule"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property string openMenu: ""
    function toggleMenu(name: string) { openMenu = openMenu === name ? "" : name }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    readonly property string focusedName: Hyprland.focusedWorkspace?.name ?? ""
    readonly property var workspaceSource: {
        const out = Hyprland.workspaces.values.filter(w =>
            (w.toplevels?.values?.length ?? 0) > 0 || w.name === bar.focusedName);
        out.sort((a, b) => {
            const an = parseInt(a.name), bn = parseInt(b.name);
            const aNum = !isNaN(an), bNum = !isNaN(bn);
            if (aNum && bNum) return an - bn;
            if (aNum !== bNum) return aNum ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }
    // Keep delegates alive across unrelated Hyprland toplevel updates.
    property var shownWorkspaces: []
    onWorkspaceSourceChanged: {
        if (workspaceSource.length !== shownWorkspaces.length
                || workspaceSource.some((w, i) => w !== shownWorkspaces[i]))
            shownWorkspaces = workspaceSource;
    }
    Component.onCompleted: shownWorkspaces = workspaceSource

    function glyphsFor(workspace) {
        const seen = new Set();
        const glyphs = [];
        for (const window of (workspace.toplevels?.values ?? [])) {
            const app = String(window.lastIpcObject?.class ?? "");
            if (!app || seen.has(app)) continue;
            seen.add(app);
            glyphs.push(Icons.forClass(app));
        }
        return glyphs;
    }

    mask: Region {
        item: capsule
        radius: 15
    }

    component Glyph: Text {
        font.family: Theme.icons
        font.pixelSize: 14
        color: Theme.fg
        Layout.alignment: Qt.AlignCenter
    }

    Rectangle {
        id: capsule
        width: parent.width
        height: Theme.barHeight
        radius: 15
        color: Theme.surface

        Flickable {
            id: workspaces
            x: 12
            width: clockButton.x - x - 12
            height: parent.height
            contentWidth: workspaceRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            property Item selectedItem: null
            onContentWidthChanged: keepVisible(selectedItem)
            onWidthChanged: keepVisible(selectedItem)

            function keepVisible(item) {
                if (!item || !item.selected) return;
                const left = item.x, right = left + item.width;
                if (left < contentX) contentX = left;
                else if (right > contentX + width) contentX = right - width;
                contentX = Math.max(0, Math.min(contentX, contentWidth - width));
            }

            Row {
                id: workspaceRow
                y: 3
                spacing: 3

                Repeater {
                    model: bar.shownWorkspaces
                    BarModule {
                        id: ws
                        required property var modelData
                        readonly property bool selected: modelData.name === bar.focusedName
                        readonly property var glyphSource: bar.glyphsFor(modelData)
                        property var glyphs: []
                        onGlyphSourceChanged: {
                            if (glyphSource.length !== glyphs.length || glyphSource.some((g, i) => g !== glyphs[i]))
                                glyphs = glyphSource;
                        }
                        width: wsContent.implicitWidth + (selected ? 18 : 10)
                        height: 24
                        padding: 3
                        text: `Workspace ${modelData.name}`
                        highlighted: selected
                        onClicked: modelData.activate()
                        onSelectedChanged: {
                            if (selected) workspaces.selectedItem = ws;
                            workspaces.keepVisible(ws);
                        }
                        onXChanged: workspaces.keepVisible(ws)
                        onWidthChanged: workspaces.keepVisible(ws)
                        Component.onCompleted: {
                            glyphs = glyphSource;
                            if (selected) workspaces.selectedItem = ws;
                            workspaces.keepVisible(ws);
                        }
                        Behavior on width {
                            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                        }

                        background: Rectangle {
                            radius: ws.selected ? 8 : 12
                            color: ws.selected ? Theme.accent : (ws.hovered ? Theme.raised : "transparent")
                            border.width: ws.visualFocus ? 2 : 0
                            border.color: Theme.fg
                            Behavior on radius { NumberAnimation { duration: Theme.base } }
                            Behavior on color { ColorAnimation { duration: Theme.base } }
                        }
                        RowLayout {
                            id: wsContent
                            Layout.alignment: Qt.AlignCenter
                            spacing: 5
                            Text {
                                text: ws.modelData.name
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.maximumWidth: 36
                                color: ws.selected ? Theme.surface : Theme.secondary
                            }
                            Repeater {
                                model: ws.glyphs
                                Text {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    font.family: Theme.icons
                                    font.pixelSize: Theme.fontSize - 1
                                    color: ws.selected ? Theme.surface : Theme.accent
                                    rotation: ws.hovered ? (index % 2 ? 12 : -12) : 0
                                    Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                }
                            }
                        }
                    }
                }
            }
        }

        BarModule {
            id: clockButton
            x: bar.width / 2 - width / 2
            y: 2
            width: 80
            height: 26
            text: Qt.formatDateTime(bar.now, "dddd, d MMMM")
            highlighted: bar.openMenu === "clock"
            onClicked: bar.toggleMenu("clock")
            Text {
                text: Qt.formatDateTime(bar.now, "HH:mm")
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 0.5
                color: Theme.fg
                Layout.alignment: Qt.AlignCenter
            }
        }

        RowLayout {
            x: clockButton.x + clockButton.width + 6
            y: 2
            width: hudButton.x - x - 4
            height: 28
            spacing: 2

            BarModule {
                Layout.preferredWidth: 28
                padding: 4
                enabled: Media.player !== null
                opacity: enabled ? 1 : 0
                text: Media.player ? `${Media.player.trackTitle || Media.player.identity} · Open player` : "Open player"
                onClicked: bar.toggleMenu("home")
                Glyph { text: "\uf001"; color: Media.player?.isPlaying ? Theme.accent : Theme.secondary }
            }
            BarModule {
                Layout.preferredWidth: 28
                padding: 4
                text: Audio.muted ? "Muted · Audio controls" : `Volume ${Math.round(Audio.volume * 100)}% · Audio controls`
                enabled: Audio.ready
                onClicked: bar.toggleMenu("audio")
                onScrolled: delta => {
                    if (delta !== 0) Audio.setVolume(Audio.sink, Audio.volume + (delta > 0 ? 0.02 : -0.02));
                }
                Glyph { text: Audio.muted ? "\u{f0581}" : "\u{f057e}"; color: Audio.muted ? Theme.red : Theme.secondary }
            }
            BarModule {
                Layout.fillWidth: true
                padding: 3
                visible: Battery.present
                text: `${Battery.charging ? "Charging" : "Battery"} ${Battery.percent}% ${Battery.timeText}`
                onClicked: bar.toggleMenu("home")
                Text {
                    text: `${Battery.charging ? "+" : ""}${Battery.percent}%`
                    color: Battery.low ? Theme.red : (Battery.charging ? Theme.green : Theme.secondary)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
    }

    BarModule {
        id: hudButton
        x: bar.width - width
        y: 0
        width: 30
        height: 30
        scale: 1
        text: bar.openMenu === "" ? "Open controls" : "Close controls"
        onClicked: bar.openMenu = bar.openMenu === "" ? "home" : ""

        background: Rectangle {
            radius: 15
            color: Theme.surface
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: hudButton.hovered || bar.openMenu !== "" ? 8 : 13
                rotation: hudButton.hovered ? 12 : 0
                scale: hudButton.down ? 0.78 : 1
                Behavior on scale { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                color: bar.openMenu !== "" ? Theme.accent : Theme.glowFill
                border.width: hudButton.visualFocus ? 2 : 0
                border.color: Theme.accent
                Behavior on radius { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: Theme.base } }
            }
        }

        Item {
            Layout.alignment: Qt.AlignCenter
            implicitWidth: 16
            implicitHeight: 16
            rotation: bar.openMenu !== "" ? 135 : (hudButton.hovered ? -12 : 0)
            scale: hudButton.down ? 0.65 : 1
            Behavior on scale { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 2 } }
            Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: hudButton.hovered ? [6, 12, 6, 0][index] : index % 2 * 10 + 1
                    y: hudButton.hovered ? [0, 6, 12, 6][index] : Math.floor(index / 2) * 10 + 1
                    width: 4
                    height: 4
                    radius: 2
                    Behavior on x { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                    Behavior on y { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                    color: bar.openMenu !== "" ? Theme.surface : Theme.accent
                }
            }
        }

        // Only exceptional state needs an extra mark on the resting capsule.
        Rectangle {
            parent: hudButton
            x: 24
            y: 2
            width: 5
            height: 5
            radius: 2.5
            color: Audio.recorders.length > 0 ? Theme.red : Theme.yellow
            visible: Audio.recorders.length > 0 || (Net.device !== null && !Net.connected)
        }
    }

    Hud {
        anchorItem: hudButton
        monitor: bar.screen
        now: bar.now
        page: bar.openMenu
        onNavigate: page => bar.openMenu = page
        onDismissed: bar.openMenu = ""
    }
}
