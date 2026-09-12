import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    signal navigate(string page)

    menuWidth: 340
    title: "Appearance"
    subtitle: "Bar layout, edge, and theme packs"

    component Label: Text {
        textFormat: Text.PlainText
        color: Theme.fg
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSize - 1
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
    }

    component SectionTitle: Text {
        textFormat: Text.PlainText
        color: Theme.secondary
        font.family: Theme.headingFont
        font.pixelSize: Theme.fontSize - 3
        font.bold: true
        font.letterSpacing: 0.6
        Layout.fillWidth: true
    }

    component Choice: BarModule {
        id: choice
        property bool selected: false
        property string caption: ""
        property string glyph: ""
        property color tint: Theme.accent

        Layout.fillWidth: true
        implicitHeight: 44
        highlighted: selected
        cornerRadius: Theme.controlRadius

        Text {
            text: choice.glyph
            font.family: Theme.icons
            font.pixelSize: 17
            color: choice.selected ? Theme.accent : choice.tint
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: choice.text; font.family: Theme.headingFont; font.bold: choice.selected; Layout.fillWidth: true }
            Label { text: choice.caption; color: Theme.secondary; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true }
        }
    }

    function switchEdge(edge: string): void {
        menu.dismissed();
        Qt.callLater(() => Prefs.setEdge(edge));
    }

    SectionTitle { text: "BAR LAYOUT" }

    Choice {
        text: "Pill"
        glyph: "\u{f0356}"
        caption: "Compact and floating"
        selected: Prefs.barMode === "pill"
        onClicked: Prefs.setBarMode("pill")
    }

    Choice {
        text: "Full bar"
        glyph: "\u{f0a71}"
        caption: "Spans the entire screen edge"
        selected: Prefs.barMode === "full"
        onClicked: Prefs.setBarMode("full")
    }

    Choice {
        text: "Rail"
        glyph: "\u{f0356}"
        caption: "Long and floating, on any edge"
        selected: Prefs.barMode === "rail"
        onClicked: Prefs.setBarMode("rail")
    }

    MenuRule {}

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

            BarModule {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                highlighted: Prefs.edge === modelData.edge
                cornerRadius: Theme.controlRadius
                onClicked: menu.switchEdge(modelData.edge)

                Label {
                    text: modelData.label
                    color: Prefs.edge === modelData.edge ? Theme.accent : Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }

    MenuRule {}

    Choice {
        text: "Theme packs"
        glyph: "\u{f0e0c}"
        caption: Theme.name || "Choose the active color palette"
        selected: false
        onClicked: menu.navigate("theme")
    }
}
