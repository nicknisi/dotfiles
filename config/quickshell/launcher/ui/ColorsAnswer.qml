import QtQuick
import qs

// ColorsAnswer.qml - a colour typed into the launcher, answered in place
// (launcher-pickers 5.3, Launcher board): padding 18, gap 18.
//
//   ┌────────┐  HEX     #82FB9C                 ↵
//   │ swatch │  RGB     rgb(130, 251, 156)
//   │ 132    │  HSL     hsl(133, 94%, 75%)
//   └────────┘  On bg   15.0 : 1              AAA
//   hackerman accent
//
// The rows are the engine's own (providers/Colors.qml answer rows), so Up and
// Down move between formats and Enter copies the selected one, as before.
Item {
    id: root

    property var engine: null
    // [{ row, index }] for the colour rows, in engine order.
    readonly property var entries: {
        const out = [];
        const rows = engine ? engine.rows : [];
        for (let i = 0; i < rows.length; i++)
            if (rows[i].answerKind === "color") out.push({ row: rows[i], index: i });
        return out;
    }
    readonly property var first: entries.length ? entries[0].row : ({})

    Column {
        id: swatchColumn
        x: 18
        y: 18
        width: 132
        spacing: 8
        Rectangle {
            id: swatch
            width: 132
            height: 132
            radius: 16
            color: root.first.swatch || "transparent"
            border.width: 1
            border.color: Tokens.hairline
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.first.caption || ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    Column {
        anchors.left: swatchColumn.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 18
        spacing: 4
        Repeater {
            model: root.entries
            Item {
                id: valueRow
                required property var modelData
                readonly property bool selected: root.engine && root.engine.selected === modelData.index
                width: parent.width
                height: 40
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Tokens.accentTint
                    opacity: valueRow.selected ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.effects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spring
                        }
                    }
                }
                Text {
                    x: 12
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: valueRow.modelData.row.subtitle
                    textFormat: Text.PlainText
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
                Text {
                    x: 12 + 70 + 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 12 - hint.implicitWidth - 12
                    text: valueRow.modelData.row.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Tokens.fg
                    font.family: "Monaspace Argon"
                    font.pixelSize: 13
                }
                Text {
                    id: hint
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: valueRow.modelData.row.hint || (valueRow.selected ? "↵" : "")
                    textFormat: Text.PlainText
                    color: Tokens.inkDim
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.engine.selectionTouched = true;
                        root.engine.selected = valueRow.modelData.index;
                        root.engine.activate();
                    }
                }
            }
        }
    }
}
