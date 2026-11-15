// Bar.qml - the classic bar's window (pill, full, rail; PLAN M4).
//
// BarView.qml draws the bar and handles its clicks, drags and wheel; this is
// what needs Quickshell around it: the layer surface on Prefs.edge, the
// Hyprland workspaces and the tray it shows, the Interrupt popup beside the
// sound module, the drop target while it is dragged, and the anchored panel
// host (Hosts/AnchoredHost.qml) that shows the control center, its sheets,
// the power menu and the calendar against the clicked module.
//
// Under SHELL_SANDBOX=1 a fixture's workspaces, focused name, status and media
// stand in for Hyprland and the services (sandbox shots).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import qs.Hosts
import "lib/WorkspaceOrder.js" as WorkspaceOrder

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    readonly property string edge: Prefs.edge
    readonly property bool vertical: Prefs.vertical
    readonly property alias view: barView
    readonly property alias host: host
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
    implicitWidth: vertical ? Theme.barHeight + 2 * Theme.barInset : screen.width
    implicitHeight: vertical ? screen.height : Theme.barHeight + 2 * Theme.barInset
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-capsule"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Caffeine's IdleInhibitor lives in ShellServices, on the Reserve window,
    // so keep-awake works in every bar mode and with one inhibitor per session.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.now = new Date()
    }

    mask: Region {
        item: barView.body
        radius: barView.radius
    }

    // The bar's own order: by Hyprland id, so creation order (today's rule);
    // a fixture's in the sandbox, in the island's order.
    readonly property bool fixtureWorkspaces: Array.isArray(Fixture.data.workspaces)
    readonly property string focusedName: fixtureWorkspaces ? String(Fixture.data.focused ?? "") : (Hyprland.focusedWorkspace?.name ?? "")
    readonly property var workspaceSource: {
        if (bar.fixtureWorkspaces)
            return WorkspaceOrder.shown(Fixture.data.workspaces, bar.focusedName).map(w => ({ name: w.name, urgent: w.urgent, activate: () => {} }));
        // Special workspaces (the scratchpad) are overlays, not places to go.
        const list = Hyprland.workspaces.values.filter(w => !w.name.startsWith("special:") && ((w.toplevels?.values?.length ?? 0) > 0 || w.name === bar.focusedName));
        list.sort((a, b) => a.id - b.id);
        return list.map(w => ({
                    name: w.name,
                    urgent: (w.toplevels?.values ?? []).some(t => t.urgent),
                    activate: () => w.activate()
                }));
    }

    // A fixture's media as a stand-in player: title, artist, playing.
    readonly property var fixturePlayer: {
        const m = Fixture.data.media;
        if (!m) return null;
        return {
            trackTitle: m.title ?? "",
            trackArtist: m.artist ?? "",
            identity: m.title ?? "",
            trackArtUrl: "",
            isPlaying: m.playing === true,
            canTogglePlaying: false,
            canGoNext: false,
            canGoPrevious: false
        };
    }

    BarView {
        id: barView
        anchors.fill: parent
        screen: bar.screen
        now: bar.now
        workspaces: bar.workspaceSource
        focusedName: bar.focusedName
        trayItems: SystemTray.items
        status: Fixture.data.status ?? null
        player: Fixture.data.media !== undefined ? bar.fixturePlayer : Media.player
        seamFrom: host.seamFrom
        seamTo: host.seamTo
        seamStartLine: host.seamStartLine
        seamEndLine: host.seamEndLine
        dpr: bar.devicePixelRatio > 0 ? bar.devicePixelRatio : 1
    }

    // Volume, brightness and the mic, beside the sound module, while no panel
    // is open.
    PopupWindow {
        id: feedback
        readonly property Item target: barView.audioButton
        anchor.item: target
        anchor.rect.x: bar.vertical ? (bar.edge === "left" ? target.width + 8 : -implicitWidth - 8) : (target.width - implicitWidth) / 2
        anchor.rect.y: bar.vertical ? 0 : (bar.edge === "top" ? target.height + 8 : -implicitHeight - 8)
        anchor.adjustment: PopupAdjustment.Slide
        visible: Interrupt.active && barView.openMenu === "" && !host.shown
        color: "transparent"
        implicitWidth: 210
        implicitHeight: 40
        mask: Region {}
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Tokens.surface
            border.width: 1
            border.color: Tokens.hairline
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                Text {
                    text: Interrupt.glyph
                    font.family: Theme.icons
                    color: Tokens.accent
                    font.pixelSize: 14
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Tokens.fillHigh
                    visible: Interrupt.metered
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Interrupt.fraction))
                        height: 3
                        radius: 1.5
                        color: Tokens.accent
                    }
                }
                Text {
                    text: Interrupt.label
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    color: Tokens.fg
                }
            }
        }
    }

    // Where a drop lands, while the bar is dragged toward another edge.
    PanelWindow {
        screen: bar.screen
        visible: barView.dragging && barView.dragEdge !== bar.edge
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-bar-drop-target"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Rectangle {
            readonly property bool vertical: barView.dragEdge === "left" || barView.dragEdge === "right"
            width: vertical ? 4 : 180
            height: vertical ? 180 : 4
            x: barView.dragEdge === "left" ? 8 : barView.dragEdge === "right" ? parent.width - width - 8 : (parent.width - width) / 2
            y: barView.dragEdge === "top" ? 8 : barView.dragEdge === "bottom" ? parent.height - height - 8 : (parent.height - height) / 2
            radius: 2
            color: Tokens.accent
        }
    }

    // The control center, its sheets, the power menu and the calendar, against
    // the clicked module (island-modes 12.4).
    AnchoredHost {
        id: host
        barWindow: bar
        view: barView
        // Where the bar window sits on its screen: the top-left for the top
        // and left edges, flush with the far edge for the bottom and right.
        barOrigin: Qt.point(bar.edge === "right" ? bar.screen.width - bar.width : 0, bar.edge === "bottom" ? bar.screen.height - bar.height : 0)
        now: bar.now
    }
}
