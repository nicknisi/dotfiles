// A single compact popup for the overview and all device pickers.
import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: hud

    required property Item anchorItem
    required property date now
    required property var monitor
    property string page: ""
    readonly property bool shown: page !== ""
    signal navigate(string page)
    signal dismissed()

    anchor {
        item: hud.anchorItem
        edges: Edges.Bottom | Edges.Right
        gravity: Edges.Bottom | Edges.Left
        margins.top: -4
        margins.right: -12
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
        topRightRadius: 12
        transformOrigin: Item.TopRight
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
                    text: "Back to controls"
                    onClicked: hud.navigate("home")
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
                    currentIndex: Math.max(0, ["home", "audio", "net", "bt", "theme", "clock"].indexOf(hud.page))

                    HudHome {
                        shown: hud.shown && hud.page === "home"
                        onNavigate: page => hud.navigate(page)
                    }
                    AudioMenu { shown: hud.shown && hud.page === "audio"; onDismissed: hud.dismissed() }
                    NetMenu { shown: hud.shown && hud.page === "net"; onDismissed: hud.dismissed() }
                    BtMenu { shown: hud.shown && hud.page === "bt"; onDismissed: hud.dismissed() }
                    ThemeMenu { shown: hud.shown && hud.page === "theme"; onDismissed: hud.dismissed() }
                    ClockMenu { now: hud.now; shown: hud.shown && hud.page === "clock"; onDismissed: hud.dismissed() }
                }
            }
        }
    }
}
