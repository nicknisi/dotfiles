import QtQuick
import qs
import qs.Kit
import "../lib/Calendar.js" as Calendar

// CalendarLayer.qml - the month, as the island itself (island-modes 9.4,
// main-tokens 2.5.5, Main board `cal`, 400 x 368).
//
//   ←18→ ‹ November 2026                              [‹] [›] ←18→
//        Su    Mo    Tu    We    Th    Fr    Sa
//        (1)   2     3     ...
//
// Padding 14 18 16, a column 8 apart. The header is 34 high: the back button
// (chevL 14 `inkDim` and the month in 15 / 500, padding 4 6, 6 into the
// margin; "Back to the island", to hover pinned) and the month buttons, 28
// square, radius 8, `fillLow`, 4 apart. Weekdays 11 `inkDim`, Sunday first.
// Six rows of seven cells (lib/Calendar.js), 38 high and 2 apart, each a 34
// px round day in Monaspace 13: today `accent` with `onAccent` at 500, days
// of the next and last month `inkMid`.
//
// `today` is a Date from the view (the fixture's `today` in the sandbox);
// `offset` is months from today's, reset whenever the layer opens.
Layer {
    id: cal

    property date today: new Date()
    property int offset: 0

    signal back

    readonly property var shown: Calendar.shift(today.getFullYear(), today.getMonth(), offset)
    readonly property var cells: Calendar.cells(shown.year, shown.month, today)
    readonly property string title: Calendar.title(shown.year, shown.month)
    readonly property real cellWidth: (width - 36) / 7
    readonly property alias grid: grid
    readonly property alias backButton: backButton

    width: 400
    height: 368

    onCurrentChanged: if (current) offset = 0

    Accessible.role: Accessible.Grouping
    Accessible.name: "Calendar, " + title

    Item {
        id: header
        x: 18
        y: 14
        width: parent.width - 36
        height: 34

        Rectangle {
            id: backButton
            x: -6
            anchors.verticalCenter: parent.verticalCenter
            width: backRow.implicitWidth + 12
            height: backRow.implicitHeight + 8
            radius: 8
            color: backArea.containsMouse ? Tokens.fillLow : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: "Back to the island"
            Accessible.onPressAction: cal.back()
            Row {
                id: backRow
                anchors.centerIn: parent
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevL"
                    size: 14
                    color: Tokens.inkDim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cal.title
                    color: Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.back()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [{ icon: "chevL", name: "Previous month", step: -1 }, { icon: "chev", name: "Next month", step: 1 }]
                Rectangle {
                    required property var modelData
                    width: 28
                    height: 28
                    radius: 8
                    color: monthArea.pressed ? Tokens.fillHigh : Tokens.fillLow
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: cal.offset += modelData.step
                    Icon {
                        anchors.centerIn: parent
                        name: parent.modelData.icon
                        size: 14
                        color: Tokens.fg
                    }
                    MouseArea {
                        id: monthArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cal.offset += parent.modelData.step
                    }
                }
            }
        }
    }

    Row {
        id: weekdays
        x: 18
        y: header.y + header.height + 8
        Repeater {
            model: Calendar.WEEKDAYS
            Text {
                required property string modelData
                width: cal.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }

    Grid {
        id: grid
        x: 18
        y: weekdays.y + weekdays.implicitHeight + 8
        columns: 7
        rowSpacing: 2
        Repeater {
            model: cal.cells
            Item {
                required property var modelData
                width: cal.cellWidth
                height: 38
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.day + (modelData.today ? ", today" : "")
                Rectangle {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    radius: 17
                    color: parent.modelData.today ? Tokens.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.modelData.day
                        color: parent.parent.modelData.today ? Tokens.onAccent : parent.parent.modelData.inMonth ? Tokens.fg : Tokens.inkMid
                        font.family: "Monaspace Argon"
                        font.pixelSize: 13
                        font.weight: parent.parent.modelData.today ? Font.Medium : Font.Normal
                    }
                }
            }
        }
    }
}
