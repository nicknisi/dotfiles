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
// `offset` is months from today's, reset whenever the layer opens. The hosts
// feed their clock, which ticks every second, so only the date's parts are
// read (whole numbers, which notify only when they change): the grid's cells
// are built again at midnight or on a month step, never on a tick, and the
// grid's Repeater counts the cells rather than taking the array, so even then
// its 42 delegates stay.
//
// `closable` (the classic bars' anchored host, M4): there is no level to go
// back to, so the month is a plain title with no chevron and a trailing
// close button ends the row, as on the host's other pages; `back` then means
// close.
Layer {
    id: cal

    property date today: new Date()
    property int offset: 0
    property bool closable: false
    // The back button's name: back to the island's hover.
    property string backLabel: "Back to the island"

    signal back

    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDate: today.getDate()
    readonly property var shown: Calendar.shift(todayYear, todayMonth, offset)
    readonly property var cells: Calendar.cells(shown.year, shown.month, new Date(todayYear, todayMonth, todayDate))
    readonly property string title: Calendar.title(shown.year, shown.month)
    readonly property real cellWidth: (width - 36) / 7
    readonly property alias grid: grid
    readonly property alias backButton: backButton
    readonly property alias closeButton: closeButton
    readonly property alias backChevron: backChevron

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
            Accessible.role: cal.closable ? Accessible.Heading : Accessible.Button
            Accessible.name: cal.closable ? cal.title : cal.backLabel
            Accessible.onPressAction: if (!cal.closable)
                cal.back()
            Row {
                id: backRow
                anchors.centerIn: parent
                spacing: 6
                Icon {
                    id: backChevron
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !cal.closable
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
                enabled: !cal.closable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.back()
            }
        }

        // Closes the calendar (closable): the anchored pages' trailing x.
        Rectangle {
            id: closeButton
            objectName: "calClose"
            visible: cal.closable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 28 : 0
            height: 28
            radius: 8
            color: closeArea.containsMouse ? Tokens.fillLow : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: "Close the calendar"
            Accessible.onPressAction: cal.back()
            Icon {
                anchors.centerIn: parent
                name: "x"
                size: 14
                color: Tokens.inkDim
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.back()
            }
        }

        Row {
            anchors.right: closeButton.left
            anchors.rightMargin: cal.closable ? 8 : 0
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
        // A count, not the array: a month step hands the delegates new
        // entries instead of building 42 new ones.
        Repeater {
            model: cal.cells.length
            Item {
                id: cell
                required property int index
                readonly property var entry: cal.cells[index] ?? ({ day: "", today: false, inMonth: false })
                width: cal.cellWidth
                height: 38
                Accessible.role: Accessible.StaticText
                Accessible.name: entry.day + (entry.today ? ", today" : "")
                Rectangle {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    radius: 17
                    color: cell.entry.today ? Tokens.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: cell.entry.day
                        color: cell.entry.today ? Tokens.onAccent : cell.entry.inMonth ? Tokens.fg : Tokens.inkMid
                        font.family: "Monaspace Argon"
                        font.pixelSize: 13
                        font.weight: cell.entry.today ? Font.Medium : Font.Normal
                    }
                }
            }
        }
    }
}
