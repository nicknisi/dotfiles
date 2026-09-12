import Quickshell
import QtQuick
import QtQuick.Layouts
import "MenuAnchor.js" as MenuAnchor

PopupWindow {
    id: hud
    required property Item anchorItem
    required property date now
    required property var monitor
    property string edge: "top"
    property string alignment: "end"
    property string page: ""
    readonly property bool shown: page !== ""
    readonly property var offset: MenuAnchor.position(edge, alignment,
        anchorItem?.width ?? 0, anchorItem?.height ?? 0,
        frame.width, frame.height, Theme.shadowPadding, 8)
    signal navigate(string page)
    signal dismissed()

    anchor {
        item: hud.anchorItem
        rect.x: hud.offset.x
        rect.y: hud.offset.y
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
    }
    implicitWidth: Math.min(392, Math.max(180, monitor.width - 2 * Theme.shadowPadding)) + 2 * Theme.shadowPadding
    implicitHeight: frame.height + 2 * Theme.shadowPadding
    color: "transparent"
    visible: shown && anchorItem !== null
    grabFocus: true
    onClosed: hud.dismissed()
    onPageChanged: if (shown) Qt.callLater(() => pages.children[pages.currentIndex]?.forceActiveFocus())
    onOffsetChanged: if (shown) anchor.updateAnchor()
    Connections {
        target: hud.anchorItem
        function onXChanged() { if (hud.shown) hud.anchor.updateAnchor(); }
        function onYChanged() { if (hud.shown) hud.anchor.updateAnchor(); }
    }

    ShellSurface {
        id: frame
        x: Theme.shadowPadding
        y: Theme.shadowPadding
        width: parent.width - 2 * Theme.shadowPadding
        height: body.implicitHeight + 24
        prominent: true
        SurfaceShadow { surface: frame }
        focus: true
        Keys.onEscapePressed: hud.dismissed()
        MenuNavigation { scope: frame }

        ColumnLayout {
            id: body
            x: 16
            y: 12
            width: parent.width - 32
            spacing: 12
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 22
                color: Theme.raised
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 10
                    BarModule {
                        visible: hud.page !== "home"
                        text: hud.page === "tailscale" ? "Back to network" : hud.page === "theme" ? "Back to appearance" : "Back to controls"
                        onClicked: hud.navigate(hud.page === "tailscale" ? "net" : hud.page === "theme" ? "appearance" : "home")
                        Text {
                            text: "\u{f0141}"
                            font.family: Theme.icons
                            font.pixelSize: 16
                            color: Theme.accent
                        }
                    }
                    Text {
                        text: hud.page === "home" ? "System" : hud.page === "net" ? "Network" : hud.page === "bt" ? "Bluetooth" : hud.page
                        color: Theme.fg
                        font.family: Theme.headingFont
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                        font.capitalization: Font.Capitalize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    BarModule {
                        text: "Close controls"
                        onClicked: hud.dismissed()
                        Text {
                            text: "×"
                            color: Theme.secondary
                            font.family: Theme.uiFont
                            font.pixelSize: 20
                        }
                    }
                }
            }
            Flickable {
                id: viewport
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(pages.implicitHeight, Math.max(80, hud.monitor.height - 160))
                contentWidth: width
                contentHeight: pages.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Connections {
                    target: hud
                    function onPageChanged() { viewport.contentY = 0; }
                }
                StackLayout {
                    id: pages
                    width: viewport.width
                    implicitHeight: children[currentIndex]?.implicitHeight ?? 0
                    height: implicitHeight
                    currentIndex: Math.max(0, ["home", "caffeine", "audio", "net", "bt", "display", "theme", "clock", "tailscale", "appearance"].indexOf(hud.page))
                    HudHome { shown: hud.shown && hud.page === "home"; onNavigate: page => hud.navigate(page) }
                    CaffeineMenu { shown: hud.shown && hud.page === "caffeine"; onDismissed: hud.dismissed() }
                    AudioMenu { shown: hud.shown && hud.page === "audio"; onDismissed: hud.dismissed() }
                    NetMenu { shown: hud.shown && hud.page === "net"; onNavigate: page => hud.navigate(page); onDismissed: hud.dismissed() }
                    BtMenu { shown: hud.shown && hud.page === "bt"; onDismissed: hud.dismissed() }
                    DisplayMenu { monitor: hud.monitor; shown: hud.shown && hud.page === "display"; onDismissed: hud.dismissed() }
                    ThemeMenu { shown: hud.shown && hud.page === "theme"; onDismissed: hud.dismissed() }
                    ClockMenu { now: hud.now; shown: hud.shown && hud.page === "clock"; onDismissed: hud.dismissed() }
                    TailscaleMenu { shown: hud.shown && hud.page === "tailscale"; onDismissed: hud.dismissed() }
                    AppearanceMenu { shown: hud.shown && hud.page === "appearance"; onNavigate: page => hud.navigate(page); onDismissed: hud.dismissed() }
                }
            }
        }
    }
}
