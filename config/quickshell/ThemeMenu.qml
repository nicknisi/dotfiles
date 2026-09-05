// ThemeMenu.qml - the whole theme system, from the bar.
//
// bin/theme already speaks JSON for exactly this: `theme _rows themes` hands
// back every pack with its label, tagline, seven-colour swatch and a cached
// wallpaper thumbnail. That command exists because bin/theme's `picker` wants a
// quickshell overlay; this menu is the same data at bar scale.
//
// Hovering a row previews it: the wallpaper crossfades into the header and the
// row tints toward that pack's accent. Nothing is applied until a click, so the
// whole list can be browsed without touching the machine.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    menuWidth: 360
    title: "Theme"
    subtitle: menu.hovered ? menu.hovered.tagline : menu.currentTagline

    property var rows: []
    property var hovered: null

    readonly property var currentRow: menu.rows.find(r => r.current) ?? null
    readonly property string currentTagline: menu.currentRow?.tagline ?? ""

    // The row whose wallpaper and palette the header is showing: whatever the
    // pointer is on, falling back to what is actually applied.
    readonly property var preview: menu.hovered ?? menu.currentRow

    function apply(name: string) {
        applier.command = ["theme", "set", name];
        applier.startDetached();
        menu.dismissed();
    }

    Process { id: applier }

    // Re-read on open rather than once at startup, so a pack added or a
    // wallpaper changed since login shows up without restarting the shell.
    onShownChanged: if (menu.shown) rowsProc.running = true

    Process {
        id: rowsProc
        command: ["theme", "_rows", "themes"]
        // The JSON is one line but a long one, and the default parser splits on
        // newlines, which is exactly what is wanted here.
        stdout: SplitParser {
            onRead: line => {
                try { menu.rows = JSON.parse(line) } catch (e) { /* partial read */ }
            }
        }
    }

    // ---- the wallpaper, as a header --------------------------------------
    // Two stacked images crossfading, because a single Image swapping its source
    // flashes the background through on every hover.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 84
        clip: true

        Rectangle { anchors.fill: parent; color: Theme.sunken }

        Image {
            id: shot
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            source: menu.preview?.image ? "file://" + menu.preview.image : ""
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
        }

        // The pack's own palette laid over its wallpaper, which is the fastest
        // way to tell whether a theme is going to work.
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            spacing: 3

            Repeater {
                model: menu.preview?.swatches ?? []

                Rectangle {
                    required property string modelData
                    width: 14
                    height: 14
                    radius: Theme.radius
                    color: modelData
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            font.bold: true
            color: "#ffffff"
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
            text: menu.preview?.label ?? ""
        }
    }

    // ---- the packs --------------------------------------------------------
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 300)

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list
                width: flick.width
                spacing: 1

                Repeater {
                    model: menu.rows

                    MouseArea {
                        id: row
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 28
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: menu.hovered = row.modelData
                        onExited: if (menu.hovered === row.modelData) menu.hovered = null
                        onClicked: menu.apply(row.modelData.name)

                        // Tinted with the pack's own accent rather than the
                        // current theme's, so the hover is itself a preview.
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: row.modelData.swatches[0] ?? Theme.accent
                            opacity: row.containsMouse ? 0.22 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                        }

                        // The applied pack keeps a rail, the same one the bar
                        // slides between workspaces.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.borderWidth
                            height: parent.height - 8
                            color: Theme.borderActive
                            visible: row.modelData.current
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: row.modelData.current
                                color: row.modelData.current ? Theme.fg
                                     : (row.containsMouse ? Theme.fg : Theme.muted)
                                text: row.modelData.label
                            }

                            Row {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Repeater {
                                    model: row.modelData.swatches

                                    Rectangle {
                                        required property string modelData
                                        width: 8
                                        height: 8
                                        radius: Theme.radius
                                        color: modelData
                                        opacity: row.containsMouse || row.modelData.current ? 1 : 0.55
                                        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            readonly property real overflow: flick.contentHeight - flick.height
            anchors.right: parent.right
            width: 3
            color: Theme.muted
            visible: overflow > 0
            height: Math.max(24, flick.height * flick.height / flick.contentHeight)
            y: visible ? (flick.contentY / overflow) * (flick.height - height) : 0
        }
    }

    MenuRule {}

    // ---- wallpaper --------------------------------------------------------
    // Each pack ships several. This walks them without leaving the theme.
    MouseArea {
        Layout.fillWidth: true
        implicitHeight: 24
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.run("theme bg next")

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.raised
            opacity: parent.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.icons
                font.pixelSize: 14
                color: Theme.muted
                text: "\u{f02ea}" // md image-area: f0e08 is a muted speaker in this font
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                color: Theme.muted
                text: "next wallpaper"
            }
        }
    }

    Process { id: runner }
    function run(cmd: string) {
        runner.command = ["sh", "-c", cmd];
        runner.startDetached();
    }
}
