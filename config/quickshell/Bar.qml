// One capsule per monitor, and it is the only thing the shell draws.
//
// At rest it carries workspaces, the context lane, the clock and status. When
// something happens that you have to see (volume, brightness, the mic) the same
// body narrows and takes the shape of that message, then goes back. Nothing
// else opens a window, which is why Osd.qml no longer exists.
//
// It lives on whichever screen edge you last dragged it to. Top and bottom lay
// it out left to right; left and right stand it up, and every module knows how
// to stack. Prefs remembers the edge. The exclusive zone that keeps windows off
// it belongs to Reserve.qml, so this window can let go of its edge and cover
// the screen while you drag without the desktop reflowing under your pointer.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property string edge: Prefs.edge
    readonly property bool vertical: Prefs.vertical
    readonly property int thick: Theme.barHeight

    // ---- the envelope ------------------------------------------------------
    // The window is an envelope, not the shape: longer than the capsule so the
    // body has room to change size and thicker so the squash has somewhere to
    // overshoot. It reserves nothing. While the capsule is loose (mid-drag, or
    // settling after a drop) the envelope is the whole screen, so the body can
    // be anywhere on it.
    property bool loose: false

    anchors {
        top:    bar.loose || bar.edge === "top"
        bottom: bar.loose || bar.edge === "bottom"
        left:   bar.loose || bar.edge === "left"
        right:  bar.loose || bar.edge === "right"
    }
    margins {
        top:    !bar.loose && bar.edge === "top"    ? 4 : 0
        bottom: !bar.loose && bar.edge === "bottom" ? 4 : 0
        left:   !bar.loose && bar.edge === "left"   ? 4 : 0
        right:  !bar.loose && bar.edge === "right"  ? 4 : 0
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth:  bar.vertical ? bar.thick + 64 : Math.min(760, screen.width - 16)
    implicitHeight: bar.vertical ? Math.min(760, screen.height - 16) : bar.thick + 64
    color: "transparent"
    WlrLayershell.namespace: "quickshell-capsule"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property string openMenu: ""
    function toggleMenu(name: string) { openMenu = openMenu === name ? "" : name }

    // ---- length ------------------------------------------------------------
    // A pill hugs its contents, so the resting length is whatever the resting
    // layer adds up to: it breathes as workspaces come and go and stretches
    // when the context lane has something to say. Speaking makes it shorter: a
    // brief message in a long capsule reads as a gap, and pulling in is also
    // what separates the alert from the resting shape at a glance.
    //
    // An open menu suppresses the alert. Its sliders already show the value you
    // are dragging, and having the capsule bolt out from under the popup it is
    // anchored to is worse than saying nothing.
    readonly property int envelopeLength: bar.vertical ? bar.height : bar.width
    readonly property int restLength: Math.max(360, Math.min(bar.envelopeLength - 80, rest.implicitLength + 2 * rest.pad))
    readonly property int alertLength: 320
    readonly property bool alerting: Interrupt.active && bar.openMenu === "" && !bar.loose
    readonly property int length: bar.alerting ? bar.alertLength : bar.restLength

    readonly property color alertTint: {
        if (Interrupt.kind === "mic") return Audio.micMuted ? Theme.red : Theme.green;
        if (Interrupt.kind === "brightness") return Theme.yellow;
        return Audio.muted ? Theme.red : Theme.cyan;
    }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    // ---- workspaces --------------------------------------------------------
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

    // One glyph per distinct app on the workspace. Read the app_id off the
    // Wayland toplevel: lastIpcObject is an empty object until something calls
    // Hyprland.refreshToplevels(), and nothing here does, which is where every
    // icon went.
    function glyphsFor(workspace) {
        const seen = new Set();
        const glyphs = [];
        for (const window of (workspace.toplevels?.values ?? [])) {
            const app = String(window.wayland?.appId ?? window.lastIpcObject?.class ?? "");
            if (!app || seen.has(app)) continue;
            seen.add(app);
            glyphs.push(Icons.forClass(app));
        }
        return glyphs;
    }

    // ---- where the body sits -------------------------------------------------
    // The compositor centres a surface anchored to one edge along that edge, so
    // this is where the anchored envelope's corner lands on screen.
    function envelopeOrigin(): var {
        const sw = bar.screen.width, sh = bar.screen.height;
        switch (bar.edge) {
        case "bottom": return Qt.point((sw - bar.width) / 2, sh - 4 - bar.height);
        case "left":   return Qt.point(4, (sh - bar.height) / 2);
        case "right":  return Qt.point(sw - 4 - bar.width, (sh - bar.height) / 2);
        default:       return Qt.point((sw - bar.width) / 2, 4);
        }
    }

    // The resting corner for a body of the given size, in window coordinates.
    // Anchored, the envelope already carries the 4px margin and the body sits
    // flush against its near edge. Loose, the window is the screen and the body
    // keeps the 4px itself. Going by the window's size rather than `loose`
    // covers the frames between letting go and being re-anchored.
    function restPos(cw: real, ch: real): var {
        const full = bar.width >= bar.screen.width - 1 && bar.height >= bar.screen.height - 1;
        const pad = full ? 4 : 0;
        const W = bar.width, H = bar.height;
        switch (bar.edge) {
        case "bottom": return Qt.point((W - cw) / 2, H - pad - ch);
        case "left":   return Qt.point(pad, (H - ch) / 2);
        case "right":  return Qt.point(W - pad - cw, (H - ch) / 2);
        default:       return Qt.point((W - cw) / 2, pad);
        }
    }

    function nearestEdge(cx: real, cy: real): string {
        const d = { top: cy, bottom: bar.screen.height - cy, left: cx, right: bar.screen.width - cx };
        let best = "top";
        for (const e in d) if (d[e] < d[best]) best = e;
        return best;
    }

    // The body's corner while it is under the pointer.
    property real looseX: 0
    property real looseY: 0

    // ---- the flight ----------------------------------------------------------
    // Dropping the body on another edge used to flip the layout in place while
    // both dimensions overshot at once, which read as a glitch. Instead it
    // morphs through a neutral shape: the body collapses to a dot with its
    // contents faded, the dot flies to the new edge, the orientation flips
    // while nothing is visible to jump, and the dot unfurls along the new
    // axis. Dropped back on the same edge it just springs home.
    property bool compact: false
    property real travel: 1
    property point dropCenter
    property string pendingEdge: ""

    // Where the resting body's centre will be, for the size it will have.
    readonly property var restCenter: {
        const cw = bar.vertical ? bar.thick : bar.restLength;
        const ch = bar.vertical ? bar.restLength : bar.thick;
        const p = bar.restPos(cw, ch);
        return Qt.point(p.x + cw / 2, p.y + ch / 2);
    }
    readonly property var center: Qt.point(
        bar.dropCenter.x + (bar.restCenter.x - bar.dropCenter.x) * bar.travel,
        bar.dropCenter.y + (bar.restCenter.y - bar.dropCenter.y) * bar.travel)

    SequentialAnimation {
        id: relocate
        ScriptAction { script: { bar.compact = true; bar.travel = 0; } }
        PauseAnimation { duration: Theme.base + 60 }
        ScriptAction { script: Prefs.setEdge(bar.pendingEdge) }
        NumberAnimation { target: bar; property: "travel"; from: 0; to: 1; duration: Theme.unfold; easing.type: Easing.InOutCubic }
        ScriptAction { script: bar.compact = false }
        // Long enough for the unfurl to land before the envelope re-anchors.
        PauseAnimation { duration: Theme.unfold + 80 }
        ScriptAction { script: bar.loose = false }
    }
    SequentialAnimation {
        id: snapBack
        NumberAnimation { target: bar; property: "travel"; from: 0; to: 1; duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        PauseAnimation { duration: 40 }
        ScriptAction { script: bar.loose = false }
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

    // ---- the body ----------------------------------------------------------
    Rectangle {
        id: capsule
        readonly property var rest: bar.restPos(width, height)
        x: drag.active ? bar.looseX : (bar.loose ? bar.center.x - width / 2 : capsule.rest.x)
        y: drag.active ? bar.looseY : (bar.loose ? bar.center.y - height / 2 : capsule.rest.y)
        width:  bar.compact || bar.vertical ? bar.thick : bar.length
        height: bar.compact || !bar.vertical ? bar.thick : bar.length
        radius: 15
        color: Theme.alpha(Theme.surface, Prefs.translucent ? 0.62 : 1)
        clip: true
        Behavior on color { ColorAnimation { duration: Theme.unfold } }
        Behavior on width {
            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        // Double-click the body to see through it. The buttons on top take
        // their own presses first, so this only ever hears the empty capsule.
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: Prefs.toggleTranslucent()
        }

        // Drag it to another edge. The window lets go of its edge and covers the
        // screen on the first real movement, the body follows the pointer, and
        // on release it springs to whichever edge is nearest and stays there.
        DragHandler {
            id: drag
            target: null
            acceptedButtons: Qt.LeftButton
            property point grab
            readonly property point pointer: centroid.scenePosition

            onPointerChanged: {
                if (!drag.active) return;
                bar.looseX = drag.pointer.x - drag.grab.x;
                bar.looseY = drag.pointer.y - drag.grab.y;
            }

            onActiveChanged: {
                if (drag.active) {
                    bar.openMenu = "";
                    relocate.stop();
                    snapBack.stop();
                    bar.compact = false;
                    bar.travel = 1;
                    // The pointer is measured against the body, and that offset
                    // is the same in the envelope's coordinates and the screen's,
                    // so it survives the window growing underneath it.
                    drag.grab = Qt.point(drag.pointer.x - capsule.x, drag.pointer.y - capsule.y);
                    const o = bar.envelopeOrigin();
                    bar.looseX = bar.loose ? capsule.x : o.x + capsule.x;
                    bar.looseY = bar.loose ? capsule.y : o.y + capsule.y;
                    bar.loose = true;
                } else {
                    bar.dropCenter = Qt.point(bar.looseX + capsule.width / 2, bar.looseY + capsule.height / 2);
                    bar.pendingEdge = bar.nearestEdge(bar.dropCenter.x, bar.dropCenter.y);
                    bar.travel = 0;
                    if (bar.pendingEdge === bar.edge) snapBack.restart();
                    else relocate.restart();
                }
            }
        }

        // Squash and stretch. The body flattens along the axis it is travelling
        // on and springs back, which is what makes a length change read as one
        // object changing shape rather than as two rectangles swapping places.
        property real squash: 1
        transform: Scale {
            origin.x: capsule.width / 2
            origin.y: capsule.height / 2
            xScale: bar.vertical ? capsule.squash : 2 - capsule.squash
            yScale: bar.vertical ? 2 - capsule.squash : capsule.squash
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
        // In reading order: where you are, what you are doing, when it is, how
        // the machine is, and the endcap that opens the rest. One GridLayout
        // whose flow follows the edge, so the same modules lie down along the
        // top or bottom and stand up along a side.
        Item {
            id: restLayer
            width: parent.width
            height: parent.height
            opacity: bar.alerting || bar.compact ? 0 : 1
            visible: opacity > 0
            y: bar.alerting ? -10 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }

            GridLayout {
                id: rest
                readonly property int pad: 12
                readonly property int implicitLength: bar.vertical ? implicitHeight : implicitWidth

                anchors.fill: parent
                anchors.leftMargin:   bar.vertical ? 0 : rest.pad
                anchors.rightMargin:  bar.vertical ? 0 : rest.pad
                anchors.topMargin:    bar.vertical ? rest.pad : 0
                anchors.bottomMargin: bar.vertical ? rest.pad : 0
                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 10
                columnSpacing: 10

                // ---- workspaces ----------------------------------------------
                // Capped so a long run scrolls rather than pushing the lane and
                // the clock off the end of the capsule.
                ListView {
                    id: workspaces
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth:  bar.vertical ? 24 : Math.min(contentWidth, 160)
                    Layout.preferredHeight: bar.vertical ? Math.min(contentHeight, 160) : 24
                    orientation: bar.vertical ? ListView.Vertical : ListView.Horizontal
                    spacing: 3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: bar.vertical ? contentHeight > height : contentWidth > width
                    model: bar.shownWorkspaces
                    currentIndex: bar.shownWorkspaces.findIndex(w => w.name === bar.focusedName)
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                    onCountChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: BarModule {
                        id: ws
                        required property var modelData
                        required property int index
                        readonly property bool selected: modelData.name === bar.focusedName
                        readonly property var glyphSource: bar.glyphsFor(modelData)
                        property var glyphs: []
                        onGlyphSourceChanged: {
                            if (glyphSource.length !== glyphs.length || glyphSource.some((g, i) => g !== glyphs[i]))
                                glyphs = glyphSource;
                        }
                        Component.onCompleted: glyphs = glyphSource

                        // The pill's length along the capsule; its thickness is fixed.
                        readonly property real along: (bar.vertical ? wsContent.implicitHeight : wsContent.implicitWidth) + (selected ? 18 : 10)
                        width:  bar.vertical ? 24 : ws.along
                        height: bar.vertical ? ws.along : 24
                        Behavior on width {
                            enabled: !bar.vertical
                            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                        }
                        Behavior on height {
                            enabled: bar.vertical
                            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                        }
                        padding: 3
                        stacked: bar.vertical
                        text: `Workspace ${modelData.name}`
                        highlighted: selected
                        onClicked: modelData.activate()

                        background: Rectangle {
                            radius: ws.selected ? 8 : 12
                            color: ws.selected ? Theme.accent : (ws.hovered ? Theme.raised : "transparent")
                            border.width: ws.visualFocus ? 2 : 0
                            border.color: Theme.fg
                            Behavior on radius { NumberAnimation { duration: Theme.base } }
                            Behavior on color { ColorAnimation { duration: Theme.base } }
                        }
                        GridLayout {
                            id: wsContent
                            Layout.alignment: Qt.AlignCenter
                            flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                            rowSpacing: 2
                            columnSpacing: 5
                            Text {
                                text: ws.modelData.name
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.maximumWidth: 36
                                Layout.alignment: Qt.AlignCenter
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
                                    Layout.alignment: Qt.AlignCenter
                                    color: ws.selected ? Theme.surface : Theme.accent
                                    rotation: ws.hovered ? (index % 2 ? 12 : -12) : 0
                                    Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                }
                            }
                        }
                    }
                }

                // ---- context -------------------------------------------------
                // The lane no other shell has. The rest of the capsule is about
                // the machine; this is about the work, read off the focused
                // window. A shell shows its directory and branch, Claude Code
                // shows its session behind a spinner that turns while it thinks,
                // a browser shows the page. Context.qml does the reading. Stood
                // on its side there is only room for the glyph, which for an
                // agent is the part that moves.
                Item {
                    id: lane
                    visible: Context.active
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: lane.span
                    Layout.preferredHeight: 24
                    property real span: bar.vertical ? 24 : Math.min(laneRow.implicitWidth, 240)
                    Behavior on span { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }

                    RowLayout {
                        id: laneRow
                        anchors.fill: parent
                        spacing: 7

                        Text {
                            text: Context.glyph
                            font.family: Context.isAgent ? Theme.font : Theme.icons
                            font.pixelSize: Context.isAgent ? Theme.fontSize + 1 : 13
                            color: Context.isAgent ? Theme.accent : Theme.secondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillHeight: true
                            Layout.fillWidth: bar.vertical
                            Behavior on color { ColorAnimation { duration: Theme.base } }
                        }

                        Text {
                            visible: !bar.vertical
                            text: Context.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            color: Theme.fg
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // Branch, and how far off clean. Yellow the moment there
                        // is anything uncommitted, the one thing worth a colour.
                        Text {
                            visible: !bar.vertical && Context.detail !== ""
                            text: Context.detail
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                            color: Context.dirty > 0 ? Theme.yellow : Theme.secondary
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillHeight: true
                            Behavior on color { ColorAnimation { duration: Theme.base } }
                        }
                    }
                }

                // ---- clock ---------------------------------------------------
                // Lying down, the time turns over to the date under the pointer.
                // Standing up, hours over minutes.
                BarModule {
                    id: clockButton
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth:  bar.vertical ? 24 : face.implicitWidth + 22
                    Layout.preferredHeight: bar.vertical ? 40 : 24
                    padding: bar.vertical ? 0 : 8
                    text: Qt.formatDateTime(bar.now, "dddd, d MMMM")
                    highlighted: bar.openMenu === "clock"
                    onClicked: bar.toggleMenu("clock")

                    Flip {
                        id: face
                        visible: !bar.vertical
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        flipped: clockButton.hovered
                        front: Qt.formatDateTime(bar.now, "HH:mm")
                        back: Qt.formatDateTime(bar.now, "ddd d MMM")
                        pixelSize: 14
                        bold: true
                        color: Theme.fg
                    }
                    ColumnLayout {
                        visible: bar.vertical
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: -3
                        Repeater {
                            model: ["HH", "mm"]
                            Text {
                                required property string modelData
                                text: Qt.formatDateTime(bar.now, modelData)
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                                color: Theme.fg
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Whatever length the minimum leaves over goes here, so status
                // keeps hugging the endcap.
                Item {
                    Layout.fillWidth: !bar.vertical
                    Layout.fillHeight: bar.vertical
                }

                // ---- status --------------------------------------------------
                GridLayout {
                    id: statusRow
                    Layout.alignment: Qt.AlignCenter
                    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                    rowSpacing: 2
                    columnSpacing: 2

                    BarModule {
                        Layout.preferredWidth:  bar.vertical ? 24 : 30
                        Layout.preferredHeight: bar.vertical ? 30 : 24
                        Layout.alignment: Qt.AlignCenter
                        padding: 4
                        enabled: Media.player !== null
                        opacity: enabled ? 1 : 0
                        text: Media.player ? `${Media.player.trackTitle || Media.player.identity} · Open player` : "Open player"
                        onClicked: bar.toggleMenu("home")
                        Glyph { text: ""; color: Media.player?.isPlaying ? Theme.accent : Theme.secondary }
                    }

                    BarModule {
                        Layout.preferredWidth:  bar.vertical ? 24 : 30
                        Layout.preferredHeight: bar.vertical ? 30 : 24
                        Layout.alignment: Qt.AlignCenter
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
                        Layout.alignment: Qt.AlignCenter
                        Layout.preferredWidth:  bar.vertical ? 24 : implicitWidth
                        Layout.preferredHeight: bar.vertical ? implicitHeight : 24
                        padding: bar.vertical ? 0 : 7
                        stacked: bar.vertical
                        visible: Battery.present
                        text: `${Battery.charging ? "Charging" : "Battery"} ${Battery.percent}%`
                        onClicked: bar.toggleMenu("home")

                        readonly property color tint: Battery.low ? Theme.red
                            : (Battery.charging ? Theme.green : Theme.secondary)

                        // Font Awesome's ramp, f244 empty through f240 full, with
                        // the bolt standing in while it charges. The glyph carries
                        // the level and the number the detail; either one on its
                        // own makes you work out the other. On its side the glyph
                        // turns upright.
                        Glyph {
                            text: {
                                if (Battery.charging) return "";
                                const p = Battery.percent;
                                if (p > 87) return "";
                                if (p > 62) return "";
                                if (p > 37) return "";
                                if (p > 12) return "";
                                return "";
                            }
                            color: batteryButton.tint
                            rotation: bar.vertical && !Battery.charging ? -90 : 0
                            Layout.topMargin: bar.vertical ? 6 : 0
                            Behavior on color { ColorAnimation { duration: Theme.base } }
                            Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
                        }

                        Flip {
                            Layout.fillHeight: !bar.vertical
                            Layout.fillWidth: bar.vertical
                            Layout.preferredHeight: bar.vertical ? 14 : -1
                            Layout.bottomMargin: bar.vertical ? 4 : 0
                            flipped: batteryButton.hovered
                            front: `${Battery.percent}%`
                            back: bar.vertical ? "" : Battery.timeText
                            pixelSize: bar.vertical ? Theme.fontSize - 4 : Theme.fontSize - 2
                            color: batteryButton.tint
                        }
                    }
                }

                // Room for the endcap, which sits outside the clip.
                Item {
                    Layout.preferredWidth:  bar.vertical ? 1 : hudButton.width - rest.pad
                    Layout.preferredHeight: bar.vertical ? hudButton.height - rest.pad : 1
                }
            }
        }

        // ---- speaking ------------------------------------------------------
        // The two layers pass each other instead of dissolving, so the capsule
        // reads as one body turning over to say something rather than as two
        // pictures cross-fading in the same frame.
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

            GridLayout {
                anchors.fill: parent
                anchors.leftMargin:   bar.vertical ? 0 : 16
                anchors.rightMargin:  bar.vertical ? 0 : 16
                anchors.topMargin:    bar.vertical ? 16 : 0
                anchors.bottomMargin: bar.vertical ? 16 : 0
                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 10
                columnSpacing: 10

                Glyph {
                    text: Interrupt.glyph
                    font.pixelSize: 15
                    color: bar.alertTint
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }

                // The meter fills from the start of the capsule lying down and
                // from the bottom standing up, which is the way a level reads.
                Item {
                    Layout.fillWidth: !bar.vertical
                    Layout.fillHeight: bar.vertical
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: 6
                    implicitHeight: 6
                    visible: Interrupt.metered

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Theme.raised
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        readonly property real fill: Math.max(0, Math.min(1, Interrupt.fraction))
                        width:  bar.vertical ? parent.width : parent.width * fill
                        height: bar.vertical ? parent.height * fill : parent.height
                        radius: 3
                        color: bar.alertTint
                        Behavior on width  { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
                    }
                }

                // The mic is the one message with no quantity behind it, so it
                // takes the meter's space rather than drawing an empty track.
                Item {
                    Layout.fillWidth: !bar.vertical
                    Layout.fillHeight: bar.vertical
                    visible: !Interrupt.metered
                }

                Text {
                    text: Interrupt.label
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: bar.vertical ? Theme.fontSize - 3 : Theme.fontSize - 1
                    font.bold: true
                    horizontalAlignment: bar.vertical ? Text.AlignHCenter : Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    Layout.preferredWidth: bar.vertical ? 24 : 44
                    Layout.fillHeight: !bar.vertical
                    Layout.fillWidth: bar.vertical
                }
            }
        }
    }

    // ---- the endcap --------------------------------------------------------
    // Positioned in the window's coordinates rather than the capsule's, so it
    // rides the capsule's far end without being clipped by it.
    BarModule {
        id: hudButton
        x: bar.vertical ? capsule.x : capsule.x + capsule.width - width
        y: bar.vertical ? capsule.y + capsule.height - height : capsule.y
        width: 30
        height: 30
        scale: 1
        opacity: bar.alerting || bar.compact ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.base } }
        text: bar.openMenu === "" ? "Open controls" : "Close controls"
        onClicked: bar.openMenu = bar.openMenu === "" ? "home" : ""

        background: Rectangle {
            radius: 15
            color: Theme.alpha(Theme.surface, Prefs.translucent ? 0.62 : 1)
            Behavior on color { ColorAnimation { duration: Theme.unfold } }
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
        edge: bar.edge
        monitor: bar.screen
        now: bar.now
        page: bar.openMenu
        onNavigate: page => bar.openMenu = page
        onDismissed: bar.openMenu = ""
    }
}
