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
// it belongs to Reserve.qml, and the drag itself happens on `stage`, a
// fullscreen window that exists only for the length of the flight.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData

    IdleInhibitor {
        window: bar
        enabled: Caffeine.active
    }

    readonly property string edge: Prefs.edge
    readonly property bool vertical: Prefs.vertical
    readonly property bool full: Prefs.barMode === "full"
    readonly property bool minimal: Prefs.barMode === "minimal"
    readonly property int thick: Theme.barHeight

    // ---- the envelope ------------------------------------------------------
    // The window is an envelope, not the shape: longer than the capsule so the
    // body has room to change size and thicker so the squash has somewhere to
    // overshoot. It reserves nothing; Reserve.qml does that.
    //
    // It never changes size while anything in it is visible. The compositor
    // shows a resized surface's previous buffer scaled into the new geometry
    // for a frame, which is what made a move look like the capsule flying in
    // stretched from somewhere else. So a drag happens on `stage`, and this
    // window re-anchors to the new edge while it is fully transparent, where
    // that frame has nothing to show. Keeping a screen-sized window around
    // permanently would also have avoided it, at the cost of rendering a
    // screen-sized buffer on every frame that changes; the stage costs that
    // only for the second or so it is mapped.
    anchors {
        top:    bar.edge === "top"
        bottom: bar.edge === "bottom"
        left:   bar.edge === "left"
        right:  bar.edge === "right"
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth:  bar.vertical ? bar.thick + 64 : (bar.full ? screen.width - 16 : Math.min(760, screen.width - 16))
    implicitHeight: bar.vertical ? (bar.full ? screen.height - 16 : Math.min(760, screen.height - 16)) : bar.thick + 64
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
    readonly property int restLength: bar.full ? (bar.vertical ? bar.height : bar.width)
        : Math.max(bar.minimal ? 0 : 360,
            Math.min((bar.vertical ? bar.height : bar.width) - 80, rest.implicitLength + 2 * rest.pad))
    readonly property int alertLength: 320
    readonly property bool alerting: Interrupt.active && bar.openMenu === "" && !bar.flying
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
        out.sort((a, b) => a.id - b.id);
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
    // The resting corner for a body of the given size inside a box of the given
    // size: centred along the edge, `pad` off it. Both windows include the 4px
    // gap in their contents so the shadow can draw up to the screen edge.
    function restPos(cw: real, ch: real, W: real, H: real, pad: real): var {
        switch (bar.edge) {
        case "bottom": return Qt.point((W - cw) / 2, H - pad - ch);
        case "left":   return Qt.point(pad, (H - ch) / 2);
        case "right":  return Qt.point(W - pad - cw, (H - ch) / 2);
        default:       return Qt.point((W - cw) / 2, pad);
        }
    }

    // The compositor centres a surface anchored to one edge along that edge, so
    // this is where the envelope's corner lands on screen.
    function envelopeOrigin(): var {
        const sw = bar.screen.width, sh = bar.screen.height;
        switch (bar.edge) {
        case "bottom": return Qt.point((sw - bar.width) / 2, sh - bar.height);
        case "left":   return Qt.point(0, (sh - bar.height) / 2);
        case "right":  return Qt.point(sw - bar.width, (sh - bar.height) / 2);
        default:       return Qt.point((sw - bar.width) / 2, 0);
        }
    }

    function nearestEdge(cx: real, cy: real): string {
        const d = { top: cy, bottom: bar.screen.height - cy, left: cx, right: bar.screen.width - cx };
        let best = "top";
        for (const e in d) if (d[e] < d[best]) best = e;
        return best;
    }

    // ---- the flight ----------------------------------------------------------
    // On the first real movement the body is photographed, the stage maps with
    // that picture under the pointer, and the body itself goes transparent.
    // Dropped on another edge, the picture fades as the stage's pill collapses
    // to a dot, the dot flies to the new edge, the orientation flips while
    // nothing visible can jump (the envelope re-anchors here, transparent), and
    // the pill unfurls along the new axis. Then the body comes back at full
    // opacity underneath and the pill fades off it, so the contents fade in.
    // Dropped back on the same edge the picture just springs home.
    property bool flying: false
    property real bodyOpacity: 1
    property real looseX: 0          // the body's corner under the pointer, on screen
    property real looseY: 0
    property bool compact: false
    property bool flipped: false     // the picture is of the old orientation
    property real travel: 1
    property point dropCenter
    property string pendingEdge: ""

    // Where the resting body's centre will be on screen, for the size it will have.
    readonly property var restCenter: {
        const cw = bar.vertical ? bar.thick : bar.restLength;
        const ch = bar.vertical ? bar.restLength : bar.thick;
        const p = bar.restPos(cw, ch, bar.screen.width, bar.screen.height, 4);
        return Qt.point(p.x + cw / 2, p.y + ch / 2);
    }
    readonly property var center: Qt.point(
        bar.dropCenter.x + (bar.restCenter.x - bar.dropCenter.x) * bar.travel,
        bar.dropCenter.y + (bar.restCenter.y - bar.dropCenter.y) * bar.travel)

    SequentialAnimation {
        id: relocate
        ScriptAction { script: { bar.compact = true; bar.travel = 0; } }
        PauseAnimation { duration: Theme.base + 60 }
        ScriptAction { script: { bar.flipped = true; Prefs.setEdge(bar.pendingEdge); } }
        NumberAnimation { target: bar; property: "travel"; from: 0; to: 1; duration: Theme.unfold; easing.type: Easing.InOutCubic }
        ScriptAction { script: bar.compact = false }
        PauseAnimation { duration: Theme.unfold + 40 }
        ScriptAction { script: bar.bodyOpacity = 1 }
        NumberAnimation { target: pill; property: "opacity"; to: 0; duration: 180 }
        ScriptAction { script: { bar.flying = false; pill.opacity = 1; } }
    }
    SequentialAnimation {
        id: snapBack
        NumberAnimation { target: bar; property: "travel"; from: 0; to: 1; duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        ScriptAction { script: bar.bodyOpacity = 1 }
        NumberAnimation { target: pill; property: "opacity"; to: 0; duration: 120 }
        ScriptAction { script: { bar.flying = false; pill.opacity = 1; } }
    }

    mask: Region {
        item: body
        radius: bar.full ? 0 : 15
    }

    component Glyph: Text {
        font.family: Theme.icons
        font.pixelSize: 14
        color: Theme.fg
        Layout.alignment: Qt.AlignCenter
    }

    // ---- the body ----------------------------------------------------------
    // Capsule and endcap under one item, so the photograph the stage takes on
    // pickup has both, and so the squash moves both.
    Item {
        id: body
        readonly property var rest: bar.restPos(width, height, bar.width, bar.height, 4)
        x: body.rest.x
        y: body.rest.y
        width:  bar.vertical ? bar.thick : bar.length
        height: bar.vertical ? bar.length : bar.thick
        opacity: bar.bodyOpacity
        Behavior on width {
            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        // The drag snapshot captures the body; the stage adds its own shadow.
        SurfaceShadow { surface: capsule; visible: !bar.full && !drag.active }

        Rectangle {
            id: capsule
            anchors.fill: parent
            radius: bar.full ? 0 : 15
            color: Theme.alpha(Theme.surface, Prefs.translucent ? 0.62 : 1)
            clip: true
            Behavior on color { ColorAnimation { duration: Theme.unfold } }

            // Double-click the body to see through it. The buttons on top take
            // their own presses first, so this only ever hears the empty capsule.
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: Prefs.toggleTranslucent()
            }

            // Drag it to another edge. The pointer stays with this window for the
            // whole drag (an implicit grab), so it keeps reporting even when it is
            // far outside the envelope; the stage just draws where it says.
            DragHandler {
                id: drag
                target: null
                acceptedButtons: Qt.LeftButton
                property point grab
                readonly property point pointer: centroid.scenePosition

                onPointerChanged: {
                    if (!drag.active || !bar.flying) return;
                    const o = bar.envelopeOrigin();
                    bar.looseX = o.x + drag.pointer.x - drag.grab.x;
                    bar.looseY = o.y + drag.pointer.y - drag.grab.y;
                }

                onActiveChanged: {
                    if (drag.active) {
                        bar.openMenu = "";
                        relocate.stop();
                        snapBack.stop();
                        bar.compact = false;
                        bar.flipped = false;
                        bar.travel = 1;
                        drag.grab = Qt.point(drag.pointer.x - body.x, drag.pointer.y - body.y);
                        const o = bar.envelopeOrigin();
                        bar.looseX = o.x + body.x;
                        bar.looseY = o.y + body.y;
                        // Photographed at the screen's density so it stays crisp,
                        // then the stage takes over the same frame the body vanishes.
                        const dpr = bar.screen.devicePixelRatio || 1;
                        body.grabToImage(result => {
                            if (!drag.active) return;   // let go before the shutter
                            stage.snapshot = result.url;
                            bar.bodyOpacity = 0;
                            bar.flying = true;
                        }, Qt.size(Math.round(body.width * dpr), Math.round(body.height * dpr)));
                    } else {
                        if (!bar.flying) return;        // nothing ever left the envelope
                        bar.dropCenter = Qt.point(bar.looseX + pill.width / 2, bar.looseY + pill.height / 2);
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
            // In reading order: Nick, where you are, what you are doing, when it
            // is, and how the machine is. One GridLayout
            // whose flow follows the edge, so the same modules lie down along the
            // top or bottom and stand up along a side.
            Item {
                id: restLayer
                width: parent.width
                height: parent.height
                opacity: bar.alerting ? 0 : 1
                // Never hidden for the flight: the body goes transparent as a whole
                // instead, and a layout that is not visible does not re-measure,
                // which the unfurl depends on after the flow flips.
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

                    // Room for Nick at the leading edge, outside the capsule's clip.
                    Item {
                        Layout.preferredWidth:  bar.vertical ? 1 : hudButton.width - rest.pad
                        Layout.preferredHeight: bar.vertical ? hudButton.height - rest.pad : 1
                    }

                    // ---- workspaces ----------------------------------------------
                    // Capped so a long run scrolls rather than pushing the lane and
                    // the clock off the end of the capsule.
                    ListView {
                        id: workspaces
                        visible: !bar.minimal
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
                        visible: !bar.minimal && (!bar.full || bar.vertical) && Context.active
                        Layout.alignment: Qt.AlignCenter
                        Layout.preferredWidth: lane.span
                        Layout.fillWidth: !bar.vertical
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
                        visible: !bar.full || bar.vertical
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
                    // keeps hugging the trailing edge.
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
                            id: awakeButton
                            Layout.preferredWidth:  bar.vertical ? 24 : 30
                            Layout.preferredHeight: bar.vertical ? 30 : 24
                            Layout.alignment: Qt.AlignCenter
                            padding: 4
                            text: Caffeine.active ? `Coffee full · ${Caffeine.status}`
                                : `Coffee empty · ${Caffeine.durationLabel(Caffeine.selectedMinutes)} timer`
                            highlighted: Caffeine.active || bar.openMenu === "caffeine"
                            onClicked: bar.toggleMenu("caffeine")
                            Glyph {
                                text: Caffeine.active ? "\u{f0176}" : "\u{f06ca}"
                                color: Caffeine.active ? Theme.accent : Theme.secondary
                                rotation: Caffeine.active ? -5 : 0
                                Behavior on color { ColorAnimation { duration: Theme.base } }
                                Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                            }
                        }

                        BarModule {
                            Layout.preferredWidth:  bar.vertical ? 24 : 30
                            Layout.preferredHeight: bar.vertical ? 30 : 24
                            Layout.alignment: Qt.AlignCenter
                            padding: 4
                            // Gone rather than faded when there is no player, so the
                            // pill closes up instead of keeping a blank 30px.
                            visible: !bar.minimal && Media.player !== null
                            text: `${Media.player?.trackTitle || Media.player?.identity || ""} · Open player`
                            onClicked: bar.toggleMenu("home")
                            Glyph { text: ""; color: Media.player?.isPlaying ? Theme.accent : Theme.secondary }
                        }

                        BarModule {
                            Layout.preferredWidth:  bar.vertical ? 24 : 30
                            Layout.preferredHeight: bar.vertical ? 30 : 24
                            Layout.alignment: Qt.AlignCenter
                            padding: 4
                            visible: !bar.minimal
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

                        // Keep notifications last so the bell owns the far edge.
                        BarModule {
                            id: notificationsButton
                            Layout.preferredWidth:  bar.vertical ? 24 : 30
                            Layout.preferredHeight: bar.vertical ? 30 : 24
                            Layout.alignment: Qt.AlignCenter
                            padding: 4
                            text: NotificationState.dnd ? "Notifications · do not disturb on"
                                : `${NotificationState.count} notifications`
                            highlighted: NotificationState.centerOpen
                            onClicked: NotificationState.toggleCenter(bar.screen)
                            Glyph {
                                text: NotificationState.dnd ? "" : ""
                                color: NotificationState.dnd ? Theme.yellow
                                    : NotificationState.unread > 0 ? Theme.accent : Theme.secondary
                            }
                            Rectangle {
                                parent: notificationsButton
                                x: 21
                                y: 1
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Theme.red
                                visible: NotificationState.unread > 0
                            }
                        }
                    }

                }

                // A full horizontal bar has enough room for a true visual center.
                // Keep the workspaces and status in their lanes, and center the
                // current title and time independently of their widths.
                RowLayout {
                    anchors.centerIn: parent
                    height: 24
                    spacing: 10
                    visible: bar.full && !bar.vertical

                    Text {
                        visible: Context.active
                        text: Context.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        elide: Text.ElideRight
                        Layout.maximumWidth: 320
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        visible: Context.active
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 12
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.secondary
                    }

                    BarModule {
                        id: fullClockButton
                        padding: 8
                        text: Qt.formatDateTime(bar.now, "dddd, d MMMM")
                        highlighted: bar.openMenu === "clock"
                        onClicked: bar.toggleMenu("clock")

                        Flip {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            flipped: fullClockButton.hovered
                            front: Qt.formatDateTime(bar.now, "HH:mm")
                            back: Qt.formatDateTime(bar.now, "ddd d MMM")
                            pixelSize: 14
                            bold: true
                            color: Theme.fg
                        }
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
        // A sibling of the capsule rather than a child, so Nick sits at the
        // leading end without being clipped by it.
        BarModule {
            id: hudButton
            x: 0
            y: 0
            width: 30
            height: 30
            padding: 0
            scale: 1
            opacity: bar.alerting ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            text: bar.openMenu === "" ? "Open controls · right-click to change bar size" : "Close controls · right-click to change bar size"
            onClicked: bar.openMenu = bar.openMenu === "" ? "home" : ""

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    bar.openMenu = "";
                    Prefs.cycleBarMode();
                }
            }

            background: Rectangle {
                radius: 8
                color: "transparent"
                border.width: hudButton.visualFocus ? 2 : 0
                border.color: Theme.accent
            }

            NickAvatar {
                Layout.alignment: Qt.AlignCenter
                page: bar.openMenu
                hovered: hudButton.hovered
                pressed: hudButton.down
                // Leave the portrait out of the photograph. The stage draws a
                // live runner instead, so the sprite doesn't freeze mid-stride.
                visible: !drag.active
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
                visible: Audio.recorders.length > 0 || Net.portal || (Net.device !== null && !Net.connected)
            }
        }

    }

    // ---- the stage ---------------------------------------------------------
    // A screen-sized window that exists only while the body is in flight. It
    // takes no input (the envelope keeps the pointer grab); it draws a pill
    // where the body is, wearing the photograph taken on pickup until the
    // collapse fades it, and the pill's size and place follow the same state
    // the envelope reads, so the two agree to the pixel at the handoff.
    PanelWindow {
        id: stage
        screen: bar.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: bar.flying
        mask: Region {}
        WlrLayershell.namespace: "quickshell-capsule-stage"
        WlrLayershell.layer: WlrLayer.Overlay

        property url snapshot

        SurfaceShadow { surface: pill; visible: !bar.full || bar.compact }

        Rectangle {
            id: pill
            x: drag.active ? bar.looseX : bar.center.x - width / 2
            y: drag.active ? bar.looseY : bar.center.y - height / 2
            width:  bar.compact || bar.vertical ? bar.thick : bar.restLength
            height: bar.compact || !bar.vertical ? bar.thick : bar.restLength
            radius: bar.full && !bar.compact ? 0 : 15
            color: Theme.alpha(Theme.surface, Prefs.translucent ? 0.62 : 1)
            Behavior on width {
                NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
            Behavior on height {
                NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }

            Image {
                anchors.fill: parent
                source: stage.snapshot
                // Gone once the body has been a dot: the picture is of the old
                // orientation, and the real body fades in instead.
                opacity: bar.compact || bar.flipped ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.base } }
            }

            NickAvatar {
                x: 0
                y: 0
                width: 30
                height: 30
                moving: true
                visible: bar.flying && !bar.compact && !bar.flipped
            }
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
