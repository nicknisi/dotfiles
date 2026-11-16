// BarView.qml - what the classic bar (pill, full, rail) draws and does, in the
// island's material (PLAN M4, island-modes 12, the Modes board).
//
// Bar.qml is the window around it (the layer surface, Hyprland's workspaces,
// the tray, the drop target, the anchored panel host). This file is QtQuick
// only, no Quickshell import, so tests/bar-drag.sh runs the real thing under
// qmltestrunner with stand-in services.
//
// Material: the island's `surface` (alpha 0.62 while Prefs.translucent, the
// classic bars' one holdover; double-tap the background to toggle).
//   pill  floats 8 in from its edge, 40 thick, radius 20 (h/2), a 1 px
//         `hairline` ring and the one shadow (0 10 28 `shadow`).
//   full  edge to edge along the top or the bottom, flush, square, no ring
//   rail  and no shadow: a 1 px `hairline` on the inner edge only. The rail
//         is the same strip down the left or the right (DECISION 5).
// While an anchored panel is open on a strip, its hairline leaves out the
// stretch the panel covers (seamFrom..seamTo), so strip and panel read as one
// piece (island-modes 12.4), but keeps running over a panel side that draws
// its own hairline (seamStartLine, seamEndLine): the strip's line and the
// panel's side then meet in one closed corner, as on the Modes board.
//
// Whole device pixels (dpr, the window's devicePixelRatio; PLAN risk 13): at
// scale 1.5 a 1 px ring on a half device pixel smears over three device
// columns. So the pill's ends, every module with a ring (its width) and the
// strip's inner line sit on whole device pixels, and that line is as thick
// as a 1 px ring draws there (2 device px at 1.5, like the panel's sides).
//
// Modules (BarChip): workspaces, the clock, then privacy (microphone, screen
// recording), the tray, keep awake, media, network, notifications, sound and
// the status module (battery, and the night light's moon while it is on:
// beside the battery, above it on the rail). Each is a capsule (radius h/2) in every mode,
// as the board draws the status group and the workspace marks. The module
// whose panel is open wears `accentTint`, and in the pill a 1 px `accent`
// inset ring.
//
// A click asks for a panel by name (toggleMenu): Bar.qml's AnchoredHost shows
// it against the clicked module (lib/Anchored.js MENUS says which panel each
// name is). The old Hud is gone from the classic bars.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.Kit
import "BarGeometry.js" as BarGeometry
import "lib/CcData.js" as CcData

Item {
    id: view

    // ---- fed by Bar.qml (or a test) -----------------------------------------
    // The monitor: { width, height } (a ShellScreen in the shell).
    property var screen: ({ width: 1920, height: 1080 })
    // The workspace chips in display order: [{ name, urgent, activate() }].
    property var workspaces: []
    property string focusedName: ""
    // SystemTray.items (an ObjectModel) or a plain array in tests.
    property var trayItems: []
    // The tray icon whose menu the host shows, when openMenu is "tray".
    property var trayItem: null
    property date now: new Date()
    // A fixture's `status` (sandbox shots): { wifi, battery, charging, low,
    // muted, nightlight }; null reads the services.
    property var status: null
    property var player: Media.player
    // Where an open panel joins a flush strip, along the bar (px from its
    // start); equal for none. Set by the host.
    property real seamFrom: 0
    property real seamTo: 0
    // The panel draws its hairline on the seam's start side (its left on a
    // horizontal strip, its top on the rail) or its end side: the strip's
    // line keeps covering that side's width, closing the corner.
    property bool seamStartLine: false
    property bool seamEndLine: false
    // Device pixels per logical px (Bar.qml: the window's).
    property real dpr: 1
    function snap(v: real): real {
        return Math.round(v * view.dpr) / view.dpr;
    }
    // Up to the next whole device pixel (a width that must hold its text).
    function snapUp(v: real): real {
        return Math.ceil(v * view.dpr - 0.001) / view.dpr;
    }
    // A 1 px line as a ring draws it: whole device pixels, at least one.
    readonly property real lineWidth: Math.max(1, Math.round(view.dpr)) / view.dpr

    // ---- geometry ------------------------------------------------------------
    readonly property string edge: Prefs.edge
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property string mode: Prefs.barMode || "pill"
    readonly property bool flush: BarGeometry.flush(mode)
    readonly property bool full: mode === "full"
    readonly property bool rail: mode === "rail"
    readonly property int thick: Theme.barHeight
    readonly property int inset: BarGeometry.inset(mode)
    readonly property real along: vertical ? height : width
    readonly property real mediaExtra: view.player ? Math.max(0, view.snapUp((vertical ? mediaButton.implicitHeight : mediaButton.implicitWidth) - 32)) : 0
    readonly property real targetLength: BarGeometry.length(mode, along, mediaExtra)
    readonly property real bodyLength: view.snap(Math.max(thick, targetLength))
    // Centred on whole device pixels: the media module's text makes the
    // pill's length odd, and a half-pixel bar blurs its 1 px ring (and the
    // module edges the anchored panels line up with).
    readonly property real bodyX: vertical ? (edge === "right" ? shadowRoom + inset : inset) : view.snap((width - bodyLength) / 2)
    readonly property real bodyY: vertical ? view.snap((height - bodyLength) / 2) : (edge === "bottom" ? shadowRoom + inset : inset)
    // Room for the pill's shadow (0 10 28) on its inner side, the island's
    // SHADOW_ROOM (lib/IslandMachine.js): without it the window cut the shadow
    // off 8 px under the pill, a hard line on light packs. Transparent and
    // outside the input mask (Bar.qml's Region is the body); the reserve stays
    // Theme.barExtent (Reserve.qml). The strips draw no shadow and take none.
    readonly property int shadowRoom: flush ? 0 : BarGeometry.SHADOW_ROOM
    // How much the pill's surface grows while it is picked up (the strips
    // never move). It no longer grows while a panel is open: the anchored
    // panel sits 8 from it (lib/Anchored.js), as the launcher's free panel
    // does, and the clicked module's highlight says what is open.
    readonly property real dragExpansion: flush ? 0 : 3
    // The pill's radius: half its thickness.
    readonly property real radius: flush ? 0 : thick / 2

    implicitWidth: vertical ? thick + 2 * inset + shadowRoom : (screen?.width ?? 0)
    implicitHeight: vertical ? (screen?.height ?? 0) : thick + 2 * inset + shadowRoom

    // ---- state -----------------------------------------------------------------
    property bool suppressClicks: false
    property string dragEdge: edge
    readonly property bool dragging: drag.active
    // The panel asked for by name ("" for none): home, net, audio, caffeine,
    // media, notifications, tray, clock, appearance, battery, theme, power.
    property string openMenu: ""
    property Item menuAnchor: systemButton
    property string menuAlignment: "end"
    // A click asked for a menu (the tests count these).
    signal toggled(string name)

    readonly property alias body: body
    readonly property alias surface: surface
    readonly property alias handler: drag
    readonly property alias workspaceList: workspaceList
    readonly property alias clockButton: clockButton
    readonly property alias micButton: micButton
    readonly property alias recordButton: recordButton
    readonly property alias trayRepeater: trayRepeater
    readonly property alias awakeButton: awakeButton
    readonly property alias mediaButton: mediaButton
    readonly property alias networkButton: networkButton
    readonly property alias notificationsButton: notificationsButton
    readonly property alias audioButton: audioButton
    readonly property alias systemButton: systemButton
    readonly property alias innerLine: innerLine

    // The module item for a name in BarView (IPC: `bar open cc`, from the
    // status module).
    function moduleFor(name: string): Item {
        return ({ status: systemButton, clock: clockButton, net: networkButton, audio: audioButton, notifications: notificationsButton, media: mediaButton, awake: awakeButton, mic: micButton })[name] ?? systemButton;
    }
    // An item's rectangle in this view.
    function rectOf(item: Item): var {
        if (!item) return { x: body.x, y: body.y, width: body.width, height: body.height };
        const p = item.mapToItem(view, 0, 0);
        return { x: p.x, y: p.y, width: item.width, height: item.height };
    }
    // The bar's surface as an open panel sees it, in this view.
    function surfaceRect(): var {
        return { x: body.x, y: body.y, width: body.width, height: body.height };
    }

    Timer {
        id: clickReset
        interval: 160
        onTriggered: view.suppressClicks = false
    }

    function consumeClick(): bool {
        if (!suppressClicks)
            return false;
        suppressClicks = false;
        clickReset.stop();
        return true;
    }
    // alignment: "end" (the default: far edges aligned), "center" (the
    // clock) or "start".
    function toggleMenu(name, item, alignment) {
        if (consumeClick())
            return;
        const closing = openMenu === name && menuAnchor === item;
        menuAnchor = item;
        menuAlignment = alignment || "end";
        openMenu = closing ? "" : name;
        view.toggled(name);
    }
    function nearestEdge(x: real, y: real): string {
        return BarGeometry.nearestEdge(edge, screen.width, screen.height, width, height, x, y);
    }
    function finishDrag(): void {
        const next = dragEdge;
        if (next !== edge)
            Prefs.setEdge(next);
        openMenu = "";
        suppressClicks = true;
        clickReset.restart();
    }
    onEdgeChanged: openMenu = ""
    onModeChanged: openMenu = ""

    // The wheel over the workspaces steps through them in the order shown, no
    // wrap. Touchpads send many small deltas, so they add up to one notch.
    property real wheelAccumulator: 0
    function stepWorkspace(delta: real): void {
        wheelAccumulator += delta;
        if (Math.abs(wheelAccumulator) < 120)
            return;
        const direction = wheelAccumulator < 0 ? 1 : -1;
        wheelAccumulator = 0;
        const list = view.workspaces || [];
        const index = list.findIndex(w => w.name === view.focusedName) + direction;
        if (index >= 0 && index < list.length)
            list[index].activate();
    }

    // What the status modules read: a fixture's status, else the services.
    readonly property bool wifiOn: view.status ? view.status.wifi === true : Net.connected
    readonly property bool netAlert: view.status ? false : (Net.portal || (Net.device !== null && !Net.connected))
    readonly property bool batteryPresent: view.status ? typeof view.status.battery === "number" : Battery.present
    readonly property int batteryPercent: view.status ? (view.status.battery ?? 0) : Battery.percent
    readonly property bool batteryLow: view.status ? (view.status.low ?? view.batteryPercent <= 20) : Battery.low
    readonly property bool charging: view.status ? view.status.charging === true : Battery.charging
    // The status module's mark: the control center footer's rule
    // (CcData.batteryIcon), so the bar, hover and the footer agree.
    readonly property string batteryIconName: !view.batteryPresent ? "sliders" : CcData.batteryIcon({ percent: view.batteryPercent, charging: view.charging, low: view.batteryLow })
    readonly property bool muted: view.status ? view.status.muted === true : Audio.muted
    // The night light holds the screen (NightLight.active).
    readonly property bool nightOn: view.status ? view.status.nightlight === true : NightLight.active

    Item {
        id: body
        x: view.bodyX
        y: view.bodyY
        width: view.vertical ? view.thick : view.bodyLength
        height: view.vertical ? view.bodyLength : view.thick

        DragHandler {
            id: drag
            target: null
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            readonly property point pointer: centroid.scenePosition
            onPointerChanged: if (active)
                view.dragEdge = view.nearestEdge(pointer.x, pointer.y)
            onActiveChanged: {
                if (active) {
                    view.openMenu = "";
                    view.suppressClicks = true;
                    view.dragEdge = view.nearestEdge(pointer.x, pointer.y);
                } else if (view.suppressClicks) {
                    view.finishDrag();
                }
            }
        }

        // The pill's one shadow. The strips have none.
        RectangularShadow {
            visible: !view.flush
            anchors.fill: surface
            radius: surface.radius
            offset: Qt.vector2d(0, 10)
            blur: 28
            color: Tokens.shadow
        }
        Rectangle {
            id: surface
            property real expansion: drag.active ? view.dragExpansion : 0
            anchors.fill: parent
            anchors.margins: -expansion
            // Only the surface grows. Contents, hit targets and the reserved
            // zone stay put.
            Behavior on expansion {
                NumberAnimation {
                    duration: Motion.spatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spring
                }
            }
            radius: view.flush ? 0 : Math.min(width, height) / 2
            color: Prefs.translucent ? Qt.rgba(Tokens.surface.r, Tokens.surface.g, Tokens.surface.b, 0.62) : Tokens.surface
            border.width: drag.active || !view.flush ? 1 : 0
            border.color: drag.active ? Tokens.accent : Tokens.hairline
            // Buttons above this background keep their own clicks.
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: Prefs.toggleTranslucent()
            }
            Behavior on color {
                ColorAnimation {
                    duration: Motion.effects
                }
            }
        }
        // The strips' hairline: the inner edge only, left out where an open
        // panel joins (seamFrom..seamTo, along the bar) except over the
        // panel's own hairline sides, so the line and those sides meet.
        Item {
            id: innerLine
            visible: view.flush && !drag.active
            readonly property real thickness: view.lineWidth
            readonly property real seamFrom: Math.max(0, Math.min(view.seamFrom, view.seamTo, view.bodyLength))
            readonly property real seamTo: Math.max(seamFrom, Math.min(view.seamTo, view.bodyLength))
            readonly property real seamStart: Math.min(seamTo, seamFrom + (view.seamStartLine ? thickness : 0))
            readonly property real seamEnd: Math.max(seamStart, seamTo - (view.seamEndLine ? thickness : 0))
            readonly property bool open: seamEnd > seamStart
            x: view.edge === "left" ? parent.width - thickness : 0
            y: view.edge === "top" ? parent.height - thickness : 0
            width: view.vertical ? thickness : parent.width
            height: view.vertical ? parent.height : thickness
            Rectangle {
                objectName: "barLineBefore"
                color: Tokens.hairline
                width: view.vertical ? innerLine.thickness : (innerLine.open ? innerLine.seamStart : parent.width)
                height: view.vertical ? (innerLine.open ? innerLine.seamStart : parent.height) : innerLine.thickness
            }
            Rectangle {
                objectName: "barLineAfter"
                visible: innerLine.open && innerLine.seamEnd < view.bodyLength
                color: Tokens.hairline
                x: view.vertical ? 0 : innerLine.seamEnd
                y: view.vertical ? innerLine.seamEnd : 0
                width: view.vertical ? innerLine.thickness : parent.width - innerLine.seamEnd
                height: view.vertical ? parent.height - innerLine.seamEnd : innerLine.thickness
            }
        }
        Rectangle {
            visible: drag.active
            anchors.fill: parent
            radius: surface.radius
            color: Tokens.accentTint
            opacity: 0.6
            border.width: 1
            border.color: Tokens.accent
        }

        Item {
            id: leading
            x: view.vertical ? 0 : 8
            y: view.vertical ? 8 : 0
            width: view.vertical ? view.thick : workspaceList.width + 12
            height: view.vertical ? workspaceList.height + 12 : view.thick
            WheelHandler {
                onWheel: event => view.stepWorkspace(event.angleDelta.y)
            }
            ListView {
                id: workspaceList
                // Not a flickable list: the wheel switches workspaces instead,
                // and the current chip is scrolled into view by index below.
                interactive: false
                anchors.centerIn: parent
                width: view.vertical ? 30 : Math.min(contentWidth, Math.max(30, Math.min(body.width * 0.34, body.width - trailing.width - clockButton.width - 40)))
                height: view.vertical ? Math.min(contentHeight, Math.max(30, Math.min(body.height * 0.34, body.height - trailing.height - clockButton.height - 40))) : 28
                orientation: view.vertical ? ListView.Vertical : ListView.Horizontal
                spacing: 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // A count, not the array: Hyprland pushes a new list on every
                // event, and the chips read their entry by index.
                model: (view.workspaces || []).length
                currentIndex: (view.workspaces || []).findIndex(w => w.name === view.focusedName)
                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                onCountChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: BarChip {
                    id: workspaceChip
                    required property int index
                    readonly property var entry: (view.workspaces || [])[index] ?? null
                    readonly property string wsName: entry ? String(entry.name) : ""
                    readonly property bool selected: wsName !== "" && wsName === view.focusedName
                    // A window there wants attention (a Slack mention, a
                    // finished download). Hyprland marks the window; the chip
                    // shows it until that workspace is visited.
                    readonly property bool urgent: !selected && entry?.urgent === true
                    width: 30
                    height: 28
                    padding: 0
                    cornerRadius: height / 2
                    text: "Workspace " + wsName + (urgent ? " · needs attention" : "")
                    onClicked: if (!view.consumeClick() && entry)
                        entry.activate()
                    onScrolled: delta => view.stepWorkspace(delta)
                    background: Rectangle {
                        radius: workspaceChip.cornerRadius
                        color: workspaceChip.selected ? Tokens.accent : workspaceChip.urgent ? Tokens.accentTint : (workspaceChip.hovered ? Tokens.fillLow : "transparent")
                        FocusRing {
                            target: parent
                            show: workspaceChip.visualFocus
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: workspaceChip.wsName
                        font.family: "Monaspace Argon"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: workspaceChip.selected ? Tokens.onAccent : workspaceChip.urgent ? Tokens.accent : Tokens.inkDim
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        BarChip {
            id: clockButton
            objectName: "barClock"
            readonly property real span: view.vertical ? 48 : view.snapUp(clockText.implicitWidth + 22)
            x: view.vertical ? 4 : view.snap(Math.max(leading.x + leading.width + 6, Math.min((body.width - width) / 2, trailing.x - width - 6)))
            y: view.vertical ? view.snap(Math.max(leading.y + leading.height + 6, Math.min((body.height - height) / 2, trailing.y - height - 6))) : 4
            width: view.vertical ? view.thick - 8 : span
            height: view.vertical ? span : view.thick - 8
            padding: 4
            cornerRadius: Math.min(width, height) / 2
            ringed: !view.flush
            text: Qt.formatDateTime(view.now, "dddd, d MMMM")
            highlighted: view.openMenu === "clock"
            onClicked: view.toggleMenu("clock", clockButton, "center")
            Text {
                id: clockText
                text: Qt.formatDateTime(view.now, view.vertical ? "HH\nmm" : "HH:mm")
                font.family: "Monaspace Argon"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Tokens.fg
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignCenter
            }
        }

        Item {
            id: trailing
            readonly property real span: (view.vertical ? status.implicitHeight : status.implicitWidth) + 12
            x: view.vertical ? 0 : body.width - width - 8
            y: view.vertical ? body.height - height - 8 : 0
            width: view.vertical ? view.thick : span
            height: view.vertical ? span : view.thick
            GridLayout {
                id: status
                anchors.centerIn: parent
                flow: view.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 2
                columnSpacing: 2

                // Privacy. An app holding the microphone, and a running screen
                // recording; each shows only while true. The record icon stops
                // the recording, the mic icon opens the Sound sheet, which says
                // who is listening.
                StatusChip {
                    id: micButton
                    objectName: "barMic"
                    iconName: "mic"
                    visible: Audio.recorders.length > 0
                    tint: Tokens.bad
                    text: "Microphone in use · " + Audio.recorders.map(n => Audio.appFor(n)).join(", ")
                    highlighted: view.openMenu === "audio" && view.menuAnchor === micButton
                    onClicked: view.toggleMenu("audio", micButton)
                }
                StatusChip {
                    id: recordButton
                    objectName: "barRecord"
                    iconName: "record"
                    visible: Capture.recording
                    tint: Tokens.bad
                    text: "Recording the screen · stop"
                    onClicked: if (!view.consumeClick())
                        Capture.stop()
                }
                // StatusNotifierItem icons: 1Password, Slack, Discord, Spotify.
                // Left click is the app's own primary action, then a jump to
                // its window wherever that workspace is: the app only asks
                // Hyprland for focus, this makes sure of it. Right click opens
                // its menu (the control center's Tray sheet), middle click is
                // its secondary action, and the wheel scrolls.
                Repeater {
                    id: trayRepeater
                    model: view.trayItems
                    BarChip {
                        id: trayButton
                        required property var modelData
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 32
                        padding: 3
                        cornerRadius: 16
                        ringed: !view.flush
                        // Status.Passive is 0 in Quickshell.Services.SystemTray.
                        opacity: modelData.status === 0 ? 0.55 : 1
                        text: modelData.tooltipTitle || modelData.title || modelData.id
                        // The same item (by its SNI id when the model hands
                        // out copies).
                        highlighted: view.openMenu === "tray" && view.trayItem !== null && (view.trayItem === modelData || (modelData.id !== undefined && view.trayItem.id === modelData.id))
                        onClicked: {
                            if (view.consumeClick())
                                return;
                            if (modelData.onlyMenu) {
                                trayButton.openTrayMenu();
                                return;
                            }
                            modelData.activate();
                            NotificationState.focusApp([modelData.title, modelData.tooltipTitle, modelData.id]);
                        }
                        onScrolled: delta => modelData.scroll(Math.round(delta / 120), false)
                        function openTrayMenu() {
                            if (!modelData.hasMenu)
                                return;
                            view.trayItem = modelData;
                            view.toggleMenu("tray", trayButton);
                        }
                        Image {
                            source: trayButton.modelData.icon ?? ""
                            sourceSize.width: 16
                            sourceSize.height: 16
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            Layout.alignment: Qt.AlignCenter
                        }
                        // Sits over the button for the buttons it does not
                        // take; a left press falls through to the module.
                        Item {
                            parent: trayButton
                            anchors.fill: parent
                            TapHandler {
                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                onTapped: (point, button) => {
                                    if (button === Qt.RightButton)
                                        trayButton.openTrayMenu();
                                    else
                                        trayButton.modelData.secondaryActivate();
                                }
                            }
                        }
                    }
                }
                StatusChip {
                    id: awakeButton
                    objectName: "barAwake"
                    iconName: "coffee"
                    visible: Caffeine.active
                    tint: Tokens.accent
                    text: "Keep awake · " + Caffeine.status
                    highlighted: view.openMenu === "caffeine"
                    onClicked: view.toggleMenu("caffeine", awakeButton)
                }
                BarMedia {
                    id: mediaButton
                    player: view.player
                    vertical: view.vertical
                    showDetails: !vertical && view.along >= 800
                    suppressClicks: view.suppressClicks
                    consumeClick: () => view.consumeClick()
                    cornerRadius: 16
                    ringed: !view.flush
                    highlighted: view.openMenu === "media"
                    onClicked: view.toggleMenu("media", mediaButton)
                    Layout.preferredWidth: view.snapUp(implicitWidth)
                    Layout.preferredHeight: view.snapUp(implicitHeight)
                }
                StatusChip {
                    id: networkButton
                    objectName: "barNetwork"
                    iconName: Net.portal && !view.status ? "globe" : (view.wifiOn ? "wifi" : "wifiOff")
                    tint: view.netAlert ? Tokens.bad : (view.wifiOn ? Tokens.fg : Tokens.inkDim)
                    text: view.wifiOn ? "Network connected" : "Network disconnected"
                    highlighted: view.openMenu === "net"
                    onClicked: view.toggleMenu("net", networkButton)
                }
                StatusChip {
                    id: notificationsButton
                    objectName: "barBell"
                    iconName: NotificationState.dnd ? "bellOff" : "bell"
                    tint: NotificationState.dnd ? Tokens.inkDim : NotificationState.unread > 0 ? Tokens.accent : Tokens.fg
                    text: NotificationState.dnd ? "Notifications · do not disturb on" : NotificationState.count + " notifications"
                    highlighted: view.openMenu === "notifications"
                    // The control center's Notifications sheet: the history,
                    // Do not disturb and Clear all. Opening it reads them.
                    onClicked: {
                        if (view.consumeClick())
                            return;
                        NotificationState.markRead();
                        view.toggleMenu("notifications", notificationsButton);
                    }
                    Accessible.description: "Left-click for notifications; right-click to toggle do not disturb"
                    Item {
                        parent: notificationsButton
                        anchors.fill: parent
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: {
                                if (!view.consumeClick())
                                    NotificationState.toggleDnd();
                            }
                        }
                    }
                    Rectangle {
                        parent: notificationsButton
                        objectName: "barBellDot"
                        x: parent.width - 9
                        y: 6
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Tokens.accent
                        visible: !NotificationState.dnd && NotificationState.unread > 0
                    }
                }
                StatusChip {
                    id: audioButton
                    objectName: "barAudio"
                    iconName: view.status ? (view.muted ? "volMute" : "vol") : Audio.outputIconName
                    tint: view.muted ? Tokens.bad : Tokens.fg
                    text: (view.muted ? "Muted" : "Volume " + Math.round(Audio.volume * 100) + "%") + " · " + Audio.labelFor(Audio.sink)
                    enabled: view.status !== null || Audio.ready
                    highlighted: view.openMenu === "audio" && view.menuAnchor === audioButton
                    onClicked: view.toggleMenu("audio", audioButton)
                    onScrolled: delta => {
                        if (delta !== 0)
                            Audio.setVolume(Audio.sink, Audio.volume + (delta > 0 ? 0.02 : -0.02));
                    }
                }
                // The status module: the control center (left click) and
                // Appearance, the bar's mode and edge (right click).
                BarChip {
                    id: systemButton
                    objectName: "barStatus"
                    // Whole device pixels: the percentage's text made it
                    // 61.33 px wide, and its right ring sat on a half pixel.
                    Layout.preferredWidth: view.vertical ? 32 : view.snapUp(systemContent.implicitWidth + 16)
                    // The rail stacks the moon over the battery.
                    Layout.preferredHeight: view.vertical && view.nightOn ? view.snapUp(systemContent.implicitHeight + 16) : 32
                    padding: 3
                    cornerRadius: 16
                    ringed: !view.flush
                    text: "Control center · battery, network and quick settings"
                    Accessible.description: "Left-click for the control center; right-click for the bar's appearance"
                    highlighted: (view.openMenu === "home" || view.openMenu === "appearance" || view.openMenu === "battery" || view.openMenu === "theme" || view.openMenu === "power") && view.menuAnchor === systemButton
                    onClicked: view.toggleMenu("home", systemButton)
                    GridLayout {
                        id: systemContent
                        Layout.alignment: Qt.AlignCenter
                        flow: view.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                        rowSpacing: 5
                        columnSpacing: 5
                        Icon {
                            objectName: "barNightLight"
                            visible: view.nightOn
                            name: "moon"
                            size: 16
                            color: Tokens.fg
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            Layout.alignment: Qt.AlignCenter
                        }
                        Icon {
                            name: view.batteryIconName
                            size: 16
                            color: view.batteryLow ? Tokens.bad : Tokens.fg
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                        }
                        Text {
                            visible: view.batteryPresent && !view.vertical
                            text: view.batteryPercent + "%"
                            font.family: "Monaspace Argon"
                            font.pixelSize: 12
                            color: view.batteryLow ? Tokens.bad : Tokens.fg
                        }
                    }
                    Item {
                        parent: systemButton
                        anchors.fill: parent
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: view.toggleMenu("appearance", systemButton)
                        }
                    }
                    Rectangle {
                        parent: systemButton
                        x: parent.width - 7
                        y: 3
                        width: 5
                        height: 5
                        radius: 2.5
                        color: view.batteryLow ? Tokens.bad : Tokens.accent
                        visible: view.batteryLow || view.netAlert
                    }
                }
            }
        }
    }

    component StatusChip: BarChip {
        id: statusChip
        property string iconName
        property color tint: Tokens.fg
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        padding: 0
        cornerRadius: 16
        ringed: !view.flush
        Icon {
            name: statusChip.iconName
            size: 16
            color: statusChip.tint
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignCenter
        }
    }
}
