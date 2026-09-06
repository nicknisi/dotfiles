// One capsule per monitor, and it is the only thing the shell draws.
//
// At rest it carries workspaces, the clock and status. When something happens
// that you have to see (volume, brightness, the mic) the same body narrows and
// takes the shape of that message, then goes back. Nothing else opens a window,
// which is why Osd.qml no longer exists.
//
// Only the workspace pills stretch. The clock, status controls and morphing
// endcap never move on hover.
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
    // The window is an envelope, not the shape. It reserves only the capsule's
    // height, but it is wider and much taller than the capsule so the body has
    // room to change size, and so tooltips have somewhere to land: a layer
    // surface cannot paint outside itself, and at exactly barHeight tall every
    // tooltip was drawn off the bottom edge and never seen.
    exclusiveZone: Theme.barHeight
    implicitWidth: Math.min(520, screen.width - 16)
    implicitHeight: Theme.barHeight + 64
    color: "transparent"
    WlrLayershell.namespace: "quickshell-capsule"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property string openMenu: ""
    function toggleMenu(name: string) { openMenu = openMenu === name ? "" : name }

    // The two widths the body moves between. Speaking makes it narrower rather
    // than wider: a short message in a long capsule reads as a gap, and pulling
    // in is also what separates the alert from the resting shape at a glance.
    //
    // An open menu suppresses the alert. Its sliders already show the value you
    // are dragging, and having the capsule bolt out from under the popup it is
    // anchored to is worse than saying nothing.
    readonly property int restWidth: Math.min(440, bar.width)
    readonly property int alertWidth: Math.min(320, bar.width)
    readonly property bool alerting: Interrupt.active && bar.openMenu === ""

    readonly property color alertTint: {
        if (Interrupt.kind === "mic") return Audio.micMuted ? Theme.red : Theme.green;
        if (Interrupt.kind === "brightness") return Theme.yellow;
        return Audio.muted ? Theme.red : Theme.cyan;
    }

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
        x: (bar.width - width) / 2
        width: bar.alerting ? bar.alertWidth : bar.restWidth
        height: Theme.barHeight
        radius: 15
        color: Theme.surface
        clip: true

        Behavior on width {
            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        // Squash and stretch. The body flattens along the axis it is travelling
        // on and springs back, which is what makes a width change read as one
        // object changing shape rather than as two rectangles swapping places.
        property real squash: 1
        transform: Scale {
            origin.x: capsule.width / 2
            origin.y: capsule.height / 2
            xScale: 2 - capsule.squash
            yScale: capsule.squash
        }
        Connections {
            target: bar
            function onAlertingChanged() { pulse.restart() }
        }
        SequentialAnimation {
            id: pulse
            NumberAnimation { target: capsule; property: "squash"; to: 0.84; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: capsule; property: "squash"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
        }

        // ---- resting -------------------------------------------------------
        Item {
            id: restLayer
            width: parent.width
            height: parent.height
            opacity: bar.alerting ? 0 : 1
            visible: opacity > 0
            y: bar.alerting ? -10 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }

            Flickable {
                id: workspaces
                x: 12
                width: Math.max(0, clockButton.x - x - 12)
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
                x: restLayer.width / 2 - width / 2
                y: (parent.height - height) / 2
                width: face.implicitWidth + 22
                height: 24
                text: Qt.formatDateTime(bar.now, "dddd, d MMMM")
                highlighted: bar.openMenu === "clock"
                onClicked: bar.toggleMenu("clock")
                Flip {
                    id: face
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    flipped: clockButton.hovered
                    front: Qt.formatDateTime(bar.now, "HH:mm")
                    back: Qt.formatDateTime(bar.now, "ddd d MMM")
                    pixelSize: 14
                    bold: true
                    color: Theme.fg
                }
            }

            // Status hugs the endcap. It is anchored by its own right edge
            // rather than given a width subtracted from the capsule: that
            // subtraction came out smaller than the cluster's content, and a
            // RowLayout with too little room overflows to the right, which is
            // how the battery ended up printing underneath the endcap.
            //
            // Stretching the battery to fill the gap was the other half of it,
            // and left its hover tint spanning an inch of empty capsule.
            RowLayout {
                id: statusRow
                x: restLayer.width - hudButton.width - 6 - width
                width: implicitWidth
                height: parent.height
                spacing: 2

                BarModule {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    padding: 4
                    enabled: Media.player !== null
                    opacity: enabled ? 1 : 0
                    text: Media.player ? `${Media.player.trackTitle || Media.player.identity} \u00b7 Open player` : "Open player"
                    onClicked: bar.toggleMenu("home")
                    Glyph { text: "\uf001"; color: Media.player?.isPlaying ? Theme.accent : Theme.secondary }
                }

                BarModule {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    padding: 4
                    text: Audio.muted ? "Muted" : `Volume ${Math.round(Audio.volume * 100)}%`
                    enabled: Audio.ready
                    onClicked: bar.toggleMenu("audio")
                    onScrolled: delta => {
                        if (delta !== 0) Audio.setVolume(Audio.sink, Audio.volume + (delta > 0 ? 0.02 : -0.02));
                    }
                    Glyph { text: Audio.muted ? "\u{f0581}" : "\u{f057e}"; color: Audio.muted ? Theme.red : Theme.secondary }
                }

                BarModule {
                    id: batteryButton
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    padding: 7
                    visible: Battery.present
                    text: `${Battery.charging ? "Charging" : "Battery"} ${Battery.percent}%`
                    onClicked: bar.toggleMenu("home")

                    readonly property color tint: Battery.low ? Theme.red
                        : (Battery.charging ? Theme.green : Theme.secondary)

                    // Font Awesome's ramp, f244 empty through f240 full, with the
                    // bolt standing in while it charges. The glyph carries the level
                    // and the number carries the detail; either one on its own makes
                    // you work out the other.
                    Glyph {
                        text: {
                            if (Battery.charging) return "\uf0e7";
                            const p = Battery.percent;
                            if (p > 87) return "\uf240";
                            if (p > 62) return "\uf241";
                            if (p > 37) return "\uf242";
                            if (p > 12) return "\uf243";
                            return "\uf244";
                        }
                        color: batteryButton.tint
                        Behavior on color { ColorAnimation { duration: Theme.base } }
                    }

                    Flip {
                        Layout.fillHeight: true
                        flipped: batteryButton.hovered
                        front: `${Battery.percent}%`
                        back: Battery.timeText
                        pixelSize: Theme.fontSize - 2
                        color: batteryButton.tint
                    }
                }
            }
        }

        // ---- speaking ------------------------------------------------------
        // The two layers pass each other vertically instead of dissolving, so
        // the capsule reads as one body turning over to say something rather
        // than as two pictures cross-fading in the same frame.
        Item {
            id: alertLayer
            width: parent.width
            height: parent.height
            opacity: bar.alerting ? 1 : 0
            visible: opacity > 0
            y: bar.alerting ? 0 : 10
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            Behavior on y {
                NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Glyph {
                    text: Interrupt.glyph
                    font.pixelSize: 15
                    color: bar.alertTint
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 6
                    visible: Interrupt.metered

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.raised
                    }
                    Rectangle {
                        height: parent.height
                        radius: height / 2
                        width: parent.width * Math.max(0, Math.min(1, Interrupt.fraction))
                        color: bar.alertTint
                        Behavior on width { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
                    }
                }

                // The mic is the one message with no quantity behind it, so it
                // takes the meter's space rather than drawing an empty track.
                Item { Layout.fillWidth: true; visible: !Interrupt.metered }

                Text {
                    text: Interrupt.label
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: 44
                    Layout.fillHeight: true
                }
            }
        }
    }

    BarModule {
        id: hudButton
        // Positioned in the window's coordinates rather than the capsule's, so
        // it rides the capsule's edge without being clipped by it.
        x: capsule.x + capsule.width - width
        y: 0
        width: 30
        height: 30
        scale: 1
        opacity: bar.alerting ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.base } }
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
