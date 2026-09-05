// BarMenu.qml - the frame every bar dropdown shares.
//
// One component so the menus cannot drift apart: same border, same surface, same
// unfold, same dismissal. A menu supplies a title and its own layout children
// and gets everything else.
//
// The unfold is a shade rolling down rather than a fade. The frame is built at
// full height and a clipper above it grows from zero, so the content never
// scales or reflows, it is simply progressively revealed. The contents ride down
// on a short overshoot behind it, which is what makes it read as a physical pull
// rather than a fade-in.
import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: menu

    // The bar module this hangs from. Bar.qml is stamped per monitor, so each
    // bar owns its own menus anchored to its own modules.
    required property Item anchorItem

    property int menuWidth: 320
    property string title: ""
    property string subtitle: ""

    // Optional control parked at the right of the header, e.g. a power toggle.
    property Component accessory: null

    // Menu bodies declare layout children directly and land in this column.
    default property alias menuContent: content.data

    // What the bar sets. `visible` follows it, but lags on the way out so the
    // shade has time to roll back up.
    property bool shown: false

    // The menu never closes itself. `shown` is a binding owned by the bar, which
    // tracks which single menu is open; writing to it from in here would break
    // that binding and strand the bar's idea of the world.
    signal dismissed()

    readonly property real reveal: revealValue
    property real revealValue: 0

    Behavior on revealValue {
        NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutCubic }
    }

    onShownChanged: menu.revealValue = menu.shown ? 1 : 0

    anchor {
        item: menu.anchorItem
        // Pinned to the bar module's bottom-right corner and grown down-left, so
        // a wide menu under a narrow module near the right edge stays on screen.
        edges: Edges.Bottom | Edges.Right
        gravity: Edges.Bottom | Edges.Left
        margins.top: Theme.gap
    }

    implicitWidth: menu.menuWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    visible: menu.shown || menu.revealValue > 0.001

    // Dismissal on a click anywhere else.
    //
    // grabFocus takes an xdg-popup grab, which is the protocol's own answer to
    // this: the compositor sends popup_done on the first click outside and
    // Quickshell turns that into `closed`. HyprlandFocusGrab was the first
    // attempt and does not work here, because it grabs surfaces Hyprland tracks
    // and a PopupWindow is an xdg-popup parented to the bar's layer surface
    // rather than a surface of its own.
    //
    // The grab is also what gives NetMenu's passphrase field a keyboard.
    grabFocus: true
    onClosed: menu.dismissed()

    // ---- the shade ---------------------------------------------------------
    Item {
        anchors.fill: parent
        clip: true

        Item {
            width: parent.width
            // Grows from the top. Rounding keeps the clip edge on a whole pixel,
            // otherwise the bottom border shimmers on the way down.
            height: Math.round(frame.implicitHeight * menu.reveal)
        }

        Rectangle {
            id: frame
            width: parent.width
            implicitHeight: body.implicitHeight + 20
            height: implicitHeight
            color: Theme.surface
            radius: Theme.radius
            border.width: Theme.borderWidth
            border.color: Theme.borderIdle

            // Behind the clipper's growing height, so it is revealed rather than
            // resized, and riding a short overshoot so it settles with a nudge.
            y: (1 - menu.reveal) * -10
            opacity: Math.min(1, menu.reveal * 2)

            Behavior on y {
                NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
            }

            focus: true
            Keys.onEscapePressed: menu.dismissed()

            // The seam back to the bar: an accent hairline across the top edge
            // that opens from the middle as the shade drops. Same accent as the
            // focused window border, so the open menu reads as the focused thing
            // on screen.
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.borderWidth
                width: (frame.width - Theme.borderWidth * 2) * menu.reveal
                color: Theme.borderActive
            }

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: menu.title !== ""

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            color: Theme.fg
                            text: menu.title
                        }
                        Text {
                            Layout.fillWidth: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                            color: Theme.muted
                            elide: Text.ElideRight
                            visible: menu.subtitle !== ""
                            text: menu.subtitle
                        }
                    }

                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: menu.accessory
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.muted
                    opacity: 0.35
                    visible: menu.title !== ""
                }

                ColumnLayout {
                    id: content
                    Layout.fillWidth: true
                    spacing: 4
                }
            }
        }
    }
}
