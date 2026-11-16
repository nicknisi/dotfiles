import QtQuick
import qs
import qs.Kit

// NotifCard.qml - the control center's two newest notifications
// (control-lock 2.7, Main board `cc`).
//
//   Notifications (2)                                   Clear all    h30
//   [✦] Session finished                                      2m     h44
//       Claude Code · Island mocks are ready for review
//
// `raised`, radius 14, hairline, padding 8 12 6. The count pill is Monaspace
// 11 on `fillHigh`; "Clear all" 12 `inkDim`, padding 4 8, radius 8. Rows:
// a 28 px `fillHigh` tile (radius 8, a 14 px icon), title 13, sub 12
// `inkDim` on one elided line, time Monaspace 11 `inkDim`. A critical row has
// a 1 px `bad` ring [GUESS]. Nothing to show: one dim row, no Clear all
// [GUESS].
//
// notes: CcData.notes(...): { count, rows: [{ index, title, sub, time, icon,
// critical }] }. The Repeater counts the rows (ControlCenter says why).
Rectangle {
    id: card

    property var notes: ({ count: 0, rows: [] })

    signal clearAll
    signal open(int index)
    // The header: the full history (the Notifications sheet) [GUESS].
    signal more

    readonly property alias clearButton: clearButton
    readonly property alias rowRepeater: rows

    implicitWidth: 728
    implicitHeight: 132
    radius: 14
    color: Tokens.raised
    border.width: 1
    border.color: Tokens.hairline

    Item {
        id: header
        x: 12
        y: 8
        width: parent.width - 24
        height: 30
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Tokens.fg
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.Medium
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.more()
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: (card.notes?.count ?? 0) > 0
                width: countText.implicitWidth + 12
                height: countText.implicitHeight + 2
                radius: height / 2
                color: Tokens.fillHigh
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(card.notes?.count ?? 0)
                    color: Tokens.fg
                    textFormat: Text.PlainText
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }
            }
        }
        Rectangle {
            id: clearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: (card.notes?.rows ?? []).length > 0
            width: clearText.implicitWidth + 16
            height: clearText.implicitHeight + 8
            radius: 8
            color: clearArea.containsMouse || activeFocus ? Tokens.fillLow : "transparent"
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button
            Accessible.name: "Clear all notifications"
            Accessible.onPressAction: card.clearAll()
            Keys.onPressed: event => {
                if (event.isAutoRepeat) return;
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    card.clearAll();
                    event.accepted = true;
                }
            }
            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear all"
                color: Tokens.inkDim
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.clearAll()
            }
            FocusRing {}
        }
    }

    Column {
        x: 12
        y: header.y + header.height
        width: parent.width - 24
        Repeater {
            id: rows
            model: (card.notes?.rows ?? []).length
            Rectangle {
                id: row
                required property int index
                readonly property var entry: card.notes?.rows?.[index] ?? ({})
                objectName: "ccNote-" + index
                width: parent.width
                height: 44
                radius: 10
                color: rowArea.containsMouse || activeFocus ? Tokens.fillLow : "transparent"
                border.width: row.entry.critical ? 1 : 0
                border.color: Tokens.bad
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: (row.entry.title ?? "") + ", " + (row.entry.sub ?? "")
                Accessible.onPressAction: card.open(row.entry.index)
                Keys.onPressed: event => {
                    if (event.isAutoRepeat) return;
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        card.open(row.entry.index);
                        event.accepted = true;
                    }
                }
                Rectangle {
                    id: tileBox
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 8
                    color: Tokens.fillHigh
                    Icon {
                        anchors.centerIn: parent
                        name: row.entry.icon ?? ""
                        size: 14
                        color: Tokens.fg
                    }
                }
                Column {
                    x: tileBox.width + 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: timeText.x - 10 - x
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.entry.title ?? ""
                        color: Tokens.fg
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.entry.sub ?? ""
                        color: Tokens.inkDim
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                }
                Text {
                    id: timeText
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.entry.time ?? ""
                    color: Tokens.inkDim
                    textFormat: Text.PlainText
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.open(row.entry.index)
                }
                FocusRing {}
            }
        }
        Item {
            visible: (card.notes?.rows ?? []).length === 0
            width: parent.width
            height: 44
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "No notifications"
                color: Tokens.inkDim
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }
        }
    }
}
