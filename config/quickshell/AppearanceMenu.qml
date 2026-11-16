// AppearanceMenu.qml - the bar's mode and edge, and the way to the theme
// packs (the status module's right click; the classic bars' anchored host
// shows it on its frame, PLAN M4).
//
// In the island's material, the control center sheets' type: section labels
// Adwaita 11 / 500 `inkDim` in capitals, rows 46 high with a 16 px Lucide
// icon (Kit/Icon), a 13 title and an 11 `inkDim` caption. The current mode
// and edge sit on `accentTint` with the icon and the label in `accent`. One
// icon per mode: the pill a capsule of modules (rectangle-ellipsis), the full
// strip a bar across the top (panel-top), the rail a strip down the side
// (panel-left), the island the sparkle the Display sheet uses.
import QtQuick
import QtQuick.Layouts
import qs
import qs.Kit

BarMenu {
    id: menu

    signal navigate(string page)

    menuWidth: 340
    title: "Appearance"
    subtitle: "Bar layout, edge, and theme packs"

    component SectionTitle: Text {
        textFormat: Text.PlainText
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.66
        leftPadding: 4
        Layout.fillWidth: true
    }

    component Rule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Tokens.hairline
    }

    component Choice: BarChip {
        id: choice
        property bool selected: false
        property string caption: ""
        property string iconName: ""
        property bool chevron: false

        Layout.fillWidth: true
        implicitHeight: 46
        padding: 10
        cornerRadius: 10
        highlighted: selected

        Icon {
            name: choice.iconName
            size: 16
            color: choice.selected ? Tokens.accent : Tokens.fg
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 5
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: choice.text
                textFormat: Text.PlainText
                color: choice.selected ? Tokens.accent : Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: choice.selected ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: choice.caption
                textFormat: Text.PlainText
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Icon {
            visible: choice.chevron
            name: "chev"
            size: 14
            color: Tokens.inkDim
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter
        }
    }

    function switchEdge(edge: string): void {
        menu.dismissed();
        Qt.callLater(() => Prefs.setEdge(edge));
    }

    // Between pill, full and rail the bar stays and just reshapes (its
    // anchored panel, where this page shows, closes as it does). Entering or
    // leaving the island swaps the window this menu hangs from (the bar's
    // AnchoredHost goes with the bar), so close the menu first
    // and switch once the click has finished: destroying the window from
    // inside its own click handler would pull it out from under the click.
    function switchMode(mode: string): void {
        if (mode !== "island" && Prefs.barMode !== "island") {
            Prefs.setBarMode(mode);
            return;
        }
        menu.dismissed();
        Qt.callLater(() => Prefs.setBarMode(mode));
    }

    SectionTitle { text: "BAR LAYOUT" }

    Choice {
        objectName: "modePill"
        text: "Pill"
        iconName: "barPill"
        caption: "Compact and floating"
        selected: Prefs.barMode === "pill"
        onClicked: menu.switchMode("pill")
    }

    Choice {
        objectName: "modeFull"
        text: "Full bar"
        iconName: "barFull"
        caption: "Edge to edge, along the top or the bottom"
        selected: Prefs.barMode === "full"
        onClicked: menu.switchMode("full")
    }

    Choice {
        objectName: "modeRail"
        text: "Rail"
        iconName: "barRail"
        caption: "Full height, down the left or the right"
        selected: Prefs.barMode === "rail"
        onClicked: menu.switchMode("rail")
    }

    Choice {
        objectName: "modeIsland"
        text: "Island"
        iconName: "sparkle"
        caption: "Top centre, grows into what you open"
        selected: Prefs.barMode === "island"
        onClicked: menu.switchMode("island")
    }

    Rule {}

    SectionTitle { text: "SCREEN EDGE" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { edge: "top", label: "Top" },
                { edge: "right", label: "Right" },
                { edge: "bottom", label: "Bottom" },
                { edge: "left", label: "Left" }
            ]

            // The island always sits at the top; the edge it remembers is
            // where the bar goes back to. The full bar takes the top or the
            // bottom and the rail the left or the right: picking a side for
            // the full bar makes it the rail, and the top or the bottom for
            // the rail makes it the full bar (Prefs.setEdge).
            BarChip {
                id: edgeButton
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 32
                cornerRadius: 8
                enabled: Prefs.barMode !== "island"
                text: modelData.label
                readonly property bool current: (Prefs.barMode === "island" ? Prefs.storedEdge : Prefs.edge) === modelData.edge
                highlighted: current
                onClicked: menu.switchEdge(modelData.edge)

                Text {
                    text: edgeButton.modelData.label
                    textFormat: Text.PlainText
                    color: edgeButton.current ? Tokens.accent : Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    font.weight: edgeButton.current ? Font.Medium : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    Rule {}

    Choice {
        objectName: "themePacks"
        text: "Theme packs"
        iconName: "palette"
        caption: Theme.name || "Choose the active color palette"
        chevron: true
        selected: false
        onClicked: menu.navigate("theme")
    }
}
