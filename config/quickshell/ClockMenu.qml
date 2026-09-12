// ClockMenu.qml - the month, under the clock.
//
// The grid is built in one binding rather than by a model: six rows of seven
// cells covering the whole month plus the days either side of it, which is what
// makes every month the same height and stops the menu resizing as you page
// through the year.
import Quickshell
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    menuWidth: 260

    // The bar owns the clock, so the menu is told the time rather than keeping
    // its own, and the two can never disagree by a second.
    required property date now

    // Which month the grid is showing, as an offset from the current one. Reset
    // on close so reopening always lands on today.
    property int monthOffset: 0
    onShownChanged: if (!menu.shown) menu.monthOffset = 0

    readonly property date viewed: new Date(menu.now.getFullYear(), menu.now.getMonth() + menu.monthOffset, 1)

    title: Qt.formatDateTime(menu.viewed, "MMMM yyyy")
    subtitle: menu.monthOffset === 0 ? Qt.formatDateTime(menu.now, "dddd, d MMMM") : ""

    // Six weeks of cells starting on the Monday on or before the 1st. Each entry
    // carries the day number plus the two flags the delegate paints with, so the
    // delegate itself stays free of date arithmetic.
    readonly property var cells: {
        const first = menu.viewed;
        const month = first.getMonth();
        // getDay() is 0 for Sunday; shift so Monday is column 0.
        const lead = (first.getDay() + 6) % 7;
        const start = new Date(first.getFullYear(), month, 1 - lead);

        const today = new Date(menu.now.getFullYear(), menu.now.getMonth(), menu.now.getDate()).getTime();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.getTime() === today,
            });
        }
        return out;
    }

    accessory: RowLayout {
        spacing: 2

        Repeater {
            model: [
                { glyph: "\u{f0141}", step: -1 }, // md chevron-left
                { glyph: "\u{f0142}", step: 1 },  // md chevron-right
            ]

            MenuAction {
                required property var modelData
                implicitWidth: 20
                implicitHeight: 20
                cursorShape: Qt.PointingHandCursor
                Accessible.name: modelData.step < 0 ? "Previous month" : "Next month"
                onClicked: menu.monthOffset += modelData.step

                Text {
                    anchors.centerIn: parent
                    font.family: Theme.icons
                    font.pixelSize: 14
                    color: parent.containsMouse ? Theme.accent : Theme.muted
                    text: parent.modelData.glyph
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 1
        columnSpacing: 1

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Text {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 4
                font.bold: true
                color: Theme.muted
                text: modelData
            }
        }

        Repeater {
            model: menu.cells

            Item {
                id: cell
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 24

                // Today gets the accent block; the rest of the month is plain
                // text, and the days spilling in from the neighbouring months
                // are dimmed rather than hidden so the grid keeps its shape.
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: Theme.controlRadius
                    color: Theme.accent
                    visible: cell.modelData.today
                }

                Text {
                    anchors.centerIn: parent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: cell.modelData.today
                    color: cell.modelData.today ? Theme.surface
                         : (cell.modelData.inMonth ? Theme.fg : Theme.muted)
                    opacity: cell.modelData.inMonth ? 1 : 0.45
                    text: cell.modelData.day
                }
            }
        }
    }
}
