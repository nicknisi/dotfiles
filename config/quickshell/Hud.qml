// A single compact popup for the overview and all device pickers.
import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: hud

    required property Item anchorItem
    required property date now
    required property var monitor
    // The screen edge the capsule lives on. The popup opens away from it, and
    // the corner touching the endcap is the flattened one.
    property string edge: "top"
    readonly property bool side: hud.edge === "left" || hud.edge === "right"
    property string page: ""
    readonly property bool shown: page !== ""
    signal navigate(string page)
    signal dismissed()

    anchor {
        item: hud.anchorItem
        edges: {
            switch (hud.edge) {
            case "bottom": return Edges.Top | Edges.Left;
            case "left":   return Edges.Right | Edges.Top;
            case "right":  return Edges.Left | Edges.Top;
            default:       return Edges.Bottom | Edges.Left;
            }
        }
        gravity: {
            switch (hud.edge) {
            case "bottom": return Edges.Top | Edges.Right;
            case "left":   return Edges.Right | Edges.Bottom;
            case "right":  return Edges.Left | Edges.Bottom;
            default:       return Edges.Bottom | Edges.Right;
            }
        }
        margins.top:    hud.edge === "top" ? -4 : (hud.side ? -12 : 0)
        margins.bottom: hud.edge === "bottom" ? -4 : 0
        margins.left:   hud.edge === "left" ? -4 : (hud.side ? 0 : -12)
        margins.right:  hud.edge === "right" ? -4 : 0
    }

    // Transparent breathing room for the opening overshoot, not content padding.
    implicitWidth: Math.min(420, monitor.width - 48) + 24
    implicitHeight: frame.height + 24
    color: "transparent"
    visible: shown
    grabFocus: true
    onClosed: hud.dismissed()

    property real unfolded: 0
    onShownChanged: {
        unfolded = shown ? 1 : 0;
        if (shown) frame.forceActiveFocus();
    }
    Behavior on unfolded {
        NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    mask: Region {
        item: frame
        radius: 26
    }

    Rectangle {
        id: frame
        x: 12
        y: 12
        width: parent.width - 24
        height: body.implicitHeight + 24
        color: Theme.surface
        radius: 26
        topLeftRadius:    hud.edge === "top" || hud.edge === "left" ? 12 : 26
        topRightRadius:   hud.edge === "right" ? 12 : 26
        bottomLeftRadius: hud.edge === "bottom" ? 12 : 26
        transformOrigin: {
            switch (hud.edge) {
            case "bottom": return Item.BottomLeft;
            case "right":  return Item.TopRight;
            default:       return Item.TopLeft;
            }
        }
        scale: 0.86 + hud.unfolded * 0.14
        rotation: (1 - hud.unfolded) * -2
        opacity: Math.min(1, hud.unfolded)
        focus: true
        Keys.onEscapePressed: hud.dismissed()

        ColumnLayout {
            id: body
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                BarModule {
                    visible: hud.page !== "home"
                    text: hud.page === "tailscale" ? "Back to network" : "Back to controls"
                    onClicked: hud.navigate(hud.page === "tailscale" ? "net" : "home")
                    Text {
                        text: "\u{f0141}"
                        font.family: Theme.icons
                        font.pixelSize: 16
                        color: Theme.accent
                        Layout.alignment: Qt.AlignCenter
                    }
                }

                Text {
                    text: hud.page === "home" ? Qt.formatDateTime(hud.now, "ddd · d MMM").toUpperCase() : hud.page.toUpperCase()
                    color: Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.letterSpacing: 2
                }

                Item { Layout.fillWidth: true }

                BarModule {
                    text: "Close controls"
                    onClicked: hud.dismissed()
                    Text {
                        text: "\u00d7"
                        color: Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 20
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }

            // Flickable only constrains short screens. Normal HUD content keeps
            // its natural height, and device pickers retain their own scrolling.
            Flickable {
                id: viewport
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(pages.implicitHeight,
                    Math.max(120, hud.monitor.height - 190))
                contentWidth: width
                contentHeight: pages.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Connections {
                    target: hud
                    function onPageChanged() {
                        viewport.contentY = 0;
                        pageEntrance.restart();
                    }
                }
                ParallelAnimation {
                    id: pageEntrance
                    NumberAnimation { target: pages; property: "y"; from: 12; to: 0; duration: Theme.unfold; easing.type: Easing.OutBack }
                    NumberAnimation { target: pages; property: "opacity"; from: 0.3; to: 1; duration: Theme.base }
                }

                StackLayout {
                    id: pages
                    width: viewport.width
                    // StackLayout's implicit height is the tallest page, not
                    // the selected one. Size explicitly to avoid empty space.
                    implicitHeight: children[currentIndex]?.implicitHeight ?? 0
                    height: implicitHeight
                    currentIndex: Math.max(0, ["home", "audio", "net", "bt", "theme", "clock", "tailscale"].indexOf(hud.page))

                    HudHome {
                        shown: hud.shown && hud.page === "home"
                        onNavigate: page => hud.navigate(page)
                    }
                    AudioMenu { shown: hud.shown && hud.page === "audio"; onDismissed: hud.dismissed() }
                    NetMenu { shown: hud.shown && hud.page === "net"; onNavigate: page => hud.navigate(page); onDismissed: hud.dismissed() }
                    BtMenu { shown: hud.shown && hud.page === "bt"; onDismissed: hud.dismissed() }
                    ThemeMenu { shown: hud.shown && hud.page === "theme"; onDismissed: hud.dismissed() }
                    ClockMenu { now: hud.now; shown: hud.shown && hud.page === "clock"; onDismissed: hud.dismissed() }
                    TailscaleMenu { shown: hud.shown && hud.page === "tailscale"; onDismissed: hud.dismissed() }
                }
            }
        }
    }
}
