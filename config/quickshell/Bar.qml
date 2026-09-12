import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "BarGeometry.js" as BarGeometry

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property string edge: Prefs.edge
    readonly property bool vertical: Prefs.vertical
    readonly property string mode: Prefs.barMode || "pill"
    readonly property bool full: mode === "full"
    readonly property bool rail: mode === "rail"
    readonly property int thick: Theme.barHeight
    readonly property int inset: full ? 0 : Theme.barInset
    readonly property real along: vertical ? height : width
    readonly property real targetLength: full ? along : Math.min(along - 2 * inset, rail ? along * 0.8 : 518)
    readonly property real bodyLength: Math.max(thick, targetLength)
    readonly property real bodyX: vertical ? inset : (full ? 0 : (width - body.width) / 2)
    readonly property real bodyY: vertical ? (full ? 0 : (height - body.height) / 2) : inset
    property bool suppressClicks: false
    property string dragEdge: edge
    property string openMenu: ""
    property Item menuAnchor: systemButton
    property string menuAlignment: "end"
    property date now: new Date()

    anchors {
        top: edge === "top" || vertical
        bottom: edge === "bottom" || vertical
        left: edge === "left" || !vertical
        right: edge === "right" || !vertical
    }
    // Remap because Quickshell 0.3.1 does not commit unchanged-size moves.
    onAnchorsChanged: {
        bar.visible = false;
        Qt.callLater(() => bar.visible = true);
    }
    implicitWidth: vertical ? thick + 2 * inset : screen.width
    implicitHeight: vertical ? screen.height : thick + 2 * inset
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-capsule"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    IdleInhibitor {
        window: bar
        enabled: Caffeine.active
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.now = new Date()
    }
    Timer {
        id: clickReset
        interval: 160
        onTriggered: bar.suppressClicks = false
    }

    function consumeClick() {
        if (!suppressClicks)
            return false;
        suppressClicks = false;
        clickReset.stop();
        return true;
    }
    function toggleMenu(name, item, alignment) {
        if (consumeClick())
            return;
        const closing = openMenu === name && menuAnchor === item;
        NotificationState.closeCenter();
        menuAnchor = item;
        menuAlignment = alignment || "end";
        openMenu = closing ? "" : name;
    }
    function nearestEdge(x, y) {
        return BarGeometry.nearestEdge(edge, screen.width, screen.height, width, height, x, y);
    }
    function finishDrag() {
        const next = dragEdge;
        if (next !== edge)
            Prefs.setEdge(next);
        openMenu = "";
        suppressClicks = true;
        clickReset.restart();
        Qt.callLater(registerBell);
    }
    function registerBell() {
        NotificationState.registerAnchor(bar.screen, notificationsButton, bar.edge);
        if (bar.openMenu !== "")
            hud.anchor.updateAnchor();
    }
    Component.onCompleted: {
        shownWorkspaces = workspaceSource;
        registerBell();
    }
    Component.onDestruction: NotificationState.unregisterAnchor(bar.screen, notificationsButton)
    onEdgeChanged: {
        openMenu = "";
        Qt.callLater(registerBell);
    }
    onWidthChanged: Qt.callLater(registerBell)
    onHeightChanged: Qt.callLater(registerBell)
    Connections {
        target: Prefs
        function onBarModeChanged() {
            bar.openMenu = "";
            Qt.callLater(bar.registerBell);
        }
    }
    Connections {
        target: NotificationState
        function onCenterOpenChanged() {
            if (NotificationState.centerOpen)
                bar.openMenu = "";
        }
    }

    mask: Region {
        item: body
        radius: bar.full ? 0 : 24
    }

    readonly property string focusedName: Hyprland.focusedWorkspace?.name ?? ""
    readonly property var workspaceSource: {
        const list = Hyprland.workspaces.values.filter(w => (w.toplevels?.values?.length ?? 0) > 0 || w.name === bar.focusedName);
        list.sort((a, b) => a.id - b.id);
        return list;
    }
    property var shownWorkspaces: []
    onWorkspaceSourceChanged: shownWorkspaces = workspaceSource

    Item {
        id: body
        x: bar.bodyX
        y: bar.bodyY
        width: bar.vertical ? bar.thick : bar.bodyLength
        height: bar.vertical ? bar.bodyLength : bar.thick

        DragHandler {
            id: drag
            target: null
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            readonly property point pointer: centroid.scenePosition
            onPointerChanged: if (active)
                bar.dragEdge = bar.nearestEdge(pointer.x, pointer.y)
            onActiveChanged: {
                if (active) {
                    bar.openMenu = "";
                    NotificationState.closeCenter();
                    bar.suppressClicks = true;
                    bar.dragEdge = bar.nearestEdge(pointer.x, pointer.y);
                } else if (bar.suppressClicks) {
                    bar.finishDrag();
                }
            }
        }

        SurfaceShadow {
            surface: surface
            visible: !bar.full && !drag.active
        }
        Rectangle {
            id: surface
            anchors.fill: parent
            radius: bar.full ? 0 : 24
            color: Theme.alpha(Theme.surface, Prefs.translucent ? 0.62 : 1)
            border.width: drag.active ? 1 : (bar.full ? 0 : 1)
            border.color: drag.active ? Theme.accent : Theme.alpha(Theme.fg, 0.14)
            clip: true
            // Buttons above this background keep their own clicks.
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: Prefs.toggleTranslucent()
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.quick
                }
            }
            Rectangle {
                visible: bar.full
                x: bar.edge === "left" ? parent.width - 1 : 0
                y: bar.edge === "top" ? parent.height - 1 : 0
                width: bar.vertical ? 1 : parent.width
                height: bar.vertical ? parent.height : 1
                color: Theme.alpha(Theme.accent, 0.35)
            }
        }
        Rectangle {
            visible: drag.active
            anchors.fill: parent
            radius: surface.radius
            color: Theme.alpha(Theme.accent, 0.12)
            border.width: 1
            border.color: Theme.accent
        }

        Item {
            id: leading
            x: bar.vertical ? 0 : 8
            y: bar.vertical ? 8 : 0
            width: bar.vertical ? bar.thick : workspaces.width + 12
            height: bar.vertical ? workspaces.height + 12 : bar.thick
            ListView {
                id: workspaces
                anchors.centerIn: parent
                width: bar.vertical ? 30 : Math.min(contentWidth, Math.max(30, Math.min(body.width * 0.34, body.width - trailing.width - clockButton.width - 40)))
                height: bar.vertical ? Math.min(contentHeight, Math.max(60, body.height * 0.34)) : 28
                orientation: bar.vertical ? ListView.Vertical : ListView.Horizontal
                spacing: 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: bar.shownWorkspaces
                currentIndex: bar.shownWorkspaces.findIndex(w => w.name === bar.focusedName)
                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                onCountChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: BarModule {
                    id: workspaceButton
                    required property var modelData
                    required property int index
                    readonly property bool selected: modelData.name === bar.focusedName
                    width: 30
                    height: 28
                    padding: 2
                    text: "Workspace " + modelData.name
                    onClicked: if (!bar.consumeClick())
                        modelData.activate()
                    background: Rectangle {
                        radius: Theme.controlRadius
                        color: workspaceButton.selected ? Theme.accent : (workspaceButton.hovered ? Theme.raised : "transparent")
                        border.width: workspaceButton.visualFocus ? 2 : 0
                        border.color: Theme.fg
                    }
                    Text {
                        Layout.fillWidth: true
                        text: workspaceButton.modelData.name
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: true
                        color: workspaceButton.selected ? Theme.accentText : Theme.secondary
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        BarModule {
            id: clockButton
            readonly property real span: bar.vertical ? 54 : clockText.implicitWidth + 22
            x: bar.vertical ? 0 : Math.max(leading.x + leading.width + 6, Math.min((body.width - width) / 2, trailing.x - width - 6))
            y: bar.vertical ? (body.height - height) / 2 : 0
            width: bar.vertical ? bar.thick : span
            height: bar.vertical ? span : bar.thick
            padding: 4
            cornerRadius: Theme.controlRadius
            text: Qt.formatDateTime(bar.now, "dddd, d MMMM")
            highlighted: bar.openMenu === "clock"
            onClicked: bar.toggleMenu("clock", clockButton, "center")
            Text {
                id: clockText
                text: Qt.formatDateTime(bar.now, bar.vertical ? "HH\nmm" : "HH:mm")
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                color: Theme.fg
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignCenter
            }
        }

        Item {
            id: trailing
            readonly property real span: (bar.vertical ? status.implicitHeight : status.implicitWidth) + 12
            x: bar.vertical ? 0 : body.width - width - 8
            y: bar.vertical ? body.height - height - 8 : 0
            width: bar.vertical ? bar.thick : span
            height: bar.vertical ? span : bar.thick
            GridLayout {
                id: status
                anchors.centerIn: parent
                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 3
                columnSpacing: 3

                StatusButton {
                    id: awakeButton
                    glyph: "\u{f0176}"
                    visible: Caffeine.active
                    tint: Theme.accent
                    text: "Keep awake · " + Caffeine.status
                    highlighted: bar.openMenu === "caffeine"
                    onClicked: bar.toggleMenu("caffeine", awakeButton)
                }
                StatusButton {
                    id: mediaButton
                    glyph: ""
                    visible: Media.player !== null
                    tint: Media.player?.isPlaying ? Theme.accent : Theme.secondary
                    text: "Media controls"
                    onClicked: bar.toggleMenu("home", mediaButton)
                }
                StatusButton {
                    id: networkButton
                    glyph: Net.portal ? "󰤩" : (Net.connected ? "󰤨" : "󰤮")
                    tint: Net.portal ? Theme.yellow : (Net.device !== null && !Net.connected ? Theme.red : Theme.secondary)
                    text: Net.connected ? "Network connected" : "Network disconnected"
                    highlighted: bar.openMenu === "net"
                    onClicked: bar.toggleMenu("net", networkButton)
                }
                StatusButton {
                    id: notificationsButton
                    glyph: NotificationState.dnd ? "" : ""
                    tint: NotificationState.dnd ? Theme.yellow : NotificationState.unread > 0 ? Theme.accent : Theme.secondary
                    text: NotificationState.dnd ? "Notifications · do not disturb on" : NotificationState.count + " notifications"
                    highlighted: NotificationState.centerOpen && NotificationState.centerScreen === bar.screen
                    onClicked: {
                        if (bar.consumeClick())
                            return;
                        bar.openMenu = "";
                        bar.registerBell();
                        NotificationState.toggleCenter(bar.screen);
                    }
                }
                StatusButton {
                    id: audioButton
                    glyph: Audio.muted ? "\u{f0581}" : "\u{f057e}"
                    tint: Audio.muted ? Theme.red : Theme.secondary
                    text: Audio.muted ? "Muted" : "Volume " + Math.round(Audio.volume * 100) + "%"
                    enabled: Audio.ready
                    highlighted: bar.openMenu === "audio"
                    onClicked: bar.toggleMenu("audio", audioButton)
                    onScrolled: delta => {
                        if (delta !== 0)
                            Audio.setVolume(Audio.sink, Audio.volume + (delta > 0 ? 0.02 : -0.02));
                    }
                }
                BarModule {
                    id: systemButton
                    Layout.preferredWidth: bar.vertical ? 32 : systemContent.implicitWidth + 12
                    Layout.preferredHeight: 32
                    padding: 3
                    cornerRadius: Theme.controlRadius
                    text: "System controls · appearance and bar placement"
                    highlighted: bar.openMenu === "home" || bar.openMenu === "appearance"
                    onClicked: bar.toggleMenu("home", systemButton)
                    RowLayout {
                        id: systemContent
                        Layout.alignment: Qt.AlignCenter
                        spacing: 6
                        Text {
                            text: ""
                            font.family: Theme.icons
                            font.pixelSize: 15
                            color: Theme.fg
                        }
                        Text {
                            visible: Battery.present && !bar.vertical
                            text: Battery.percent + "%"
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: Battery.low ? Theme.red : Battery.charging ? Theme.green : Theme.secondary
                        }
                    }
                    Rectangle {
                        parent: systemButton
                        x: parent.width - 5
                        y: 1
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Audio.recorders.length > 0 || Battery.low ? Theme.red : Theme.yellow
                        visible: Audio.recorders.length > 0 || Battery.low || Net.portal || (Net.device !== null && !Net.connected)
                    }
                }
            }
        }
    }

    component StatusButton: BarModule {
        id: statusButton
        property string glyph
        property color tint: Theme.secondary
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        padding: 3
        cornerRadius: Theme.controlRadius
        Text {
            text: statusButton.glyph
            font.family: Theme.icons
            font.pixelSize: 14
            color: statusButton.tint
            Layout.alignment: Qt.AlignCenter
        }
    }

    PopupWindow {
        id: feedback
        anchor.item: audioButton
        anchor.rect.x: bar.vertical ? (bar.edge === "left" ? audioButton.width + 8 : -implicitWidth - 8) : (audioButton.width - implicitWidth) / 2
        anchor.rect.y: bar.vertical ? 0 : (bar.edge === "top" ? audioButton.height + 8 : -implicitHeight - 8)
        anchor.adjustment: PopupAdjustment.Slide
        visible: Interrupt.active && bar.openMenu === "" && !NotificationState.centerOpen
        color: "transparent"
        implicitWidth: 210
        implicitHeight: 40
        mask: Region {}
        ShellSurface {
            anchors.fill: parent
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Text {
                    text: Interrupt.glyph
                    font.family: Theme.icons
                    color: Theme.accent
                    font.pixelSize: 14
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    color: Theme.raised
                    visible: Interrupt.metered
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Interrupt.fraction))
                        height: 3
                        color: Theme.accent
                    }
                }
                Text {
                    text: Interrupt.label
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.fg
                }
            }
        }
    }

    PanelWindow {
        screen: bar.screen
        visible: drag.active && bar.dragEdge !== bar.edge
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-bar-drop-target"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Rectangle {
            readonly property bool vertical: bar.dragEdge === "left" || bar.dragEdge === "right"
            width: vertical ? 4 : 180
            height: vertical ? 180 : 4
            x: bar.dragEdge === "left" ? 8 : bar.dragEdge === "right" ? parent.width - width - 8 : (parent.width - width) / 2
            y: bar.dragEdge === "top" ? 8 : bar.dragEdge === "bottom" ? parent.height - height - 8 : (parent.height - height) / 2
            radius: 2
            color: Theme.accent
        }
    }

    Hud {
        id: hud
        anchorItem: bar.menuAnchor
        alignment: bar.menuAlignment
        edge: bar.edge
        monitor: bar.screen
        now: bar.now
        page: bar.openMenu
        onNavigate: page => bar.openMenu = page
        onDismissed: {
            bar.openMenu = "";
            bar.menuAnchor?.forceActiveFocus();
        }
    }
}
