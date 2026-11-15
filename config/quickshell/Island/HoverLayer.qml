import QtQuick
import qs
import qs.Kit

// HoverLayer.qml - PLACEHOLDER for the 720 x 136 hover state (M3 replaces it).
//
// Enough of island-modes 7 to make hover useful while the real one is built:
// what is playing on the left, the big clock in the centre, the status pill on
// the right. Two of the boards' doors already open, through the old menus
// (PLAN 1.7): the clock asks for the calendar (old Hud "clock" page) and the
// status pill asks for the control center (old Hud home). Media controls, the
// eq tile, status states and the Context line arrive in M3.
//
// Data comes in as plain values from Island/IslandView.
Layer {
    id: hover

    property string clock: ""
    property string date: ""
    // { title, artist } or null when nothing plays.
    property var media: null
    // { wifi, bt, tailscale, volume, muted, battery } as numbers and bools.
    property var status: ({})

    signal openCalendar
    signal openControlCenter
    signal pin

    width: 720
    height: 136

    // Empty hover space pins it, like the rest pill's button.
    MouseArea {
        anchors.fill: parent
        onClicked: hover.pin()
        Accessible.ignored: true
    }

    // ---- media (left, 250) ----
    Column {
        x: 18
        width: 250
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Row {
            spacing: 8
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "music"
                size: 14
                color: hover.media ? Tokens.accent : Tokens.inkDim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 226
                text: hover.media?.title || "Nothing playing"
                color: hover.media ? Tokens.fg : Tokens.inkDim
                elide: Text.ElideRight
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
        Text {
            x: 22
            width: 228
            visible: text !== ""
            text: hover.media?.artist ?? ""
            color: Tokens.inkDim
            elide: Text.ElideRight
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }

    // ---- clock (centre): a door to the calendar ----
    Rectangle {
        id: clockButton
        anchors.centerIn: parent
        width: clockColumn.implicitWidth + 16
        height: clockColumn.implicitHeight + 16
        radius: 14
        color: clockArea.containsMouse ? Tokens.fillLow : "transparent"
        Accessible.role: Accessible.Button
        Accessible.name: "Open the calendar"
        Accessible.onPressAction: hover.openCalendar()

        Column {
            id: clockColumn
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: hover.clock
                color: Tokens.fg
                font.family: "Monaspace Argon"
                font.pixelSize: 40
                font.weight: Font.Medium
                lineHeight: 44
                lineHeightMode: Text.FixedHeight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: hover.date
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }
        MouseArea {
            id: clockArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hover.openCalendar()
        }
    }

    // ---- status pill (right, 250): a door to the control center ----
    Rectangle {
        id: statusPill
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: statusRow.implicitWidth + 24
        height: 32
        radius: 16
        color: statusArea.containsMouse ? Tokens.fillHigh : Tokens.fillLow
        border.width: 1
        border.color: Tokens.hairline
        Accessible.role: Accessible.Button
        Accessible.name: "Open the control center"
        Accessible.onPressAction: hover.openControlCenter()

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 11
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "wifi"
                size: 14
                color: hover.status.wifi === false ? Tokens.inkDim : Tokens.fg
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "bt"
                size: 14
                color: hover.status.bt === false ? Tokens.inkDim : Tokens.fg
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "tailscale"
                size: 14
                color: hover.status.tailscale === false ? Tokens.inkDim : Tokens.fg
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "vol"
                size: 14
                color: hover.status.muted === true ? Tokens.inkDim : Tokens.fg
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "battery"
                    size: 14
                    color: Tokens.fg
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hover.status.battery !== undefined && hover.status.battery !== null
                    text: Math.round(Number(hover.status.battery)) + "%"
                    color: Tokens.fg
                    font.family: "Monaspace Argon"
                    font.pixelSize: 12
                }
            }
        }
        MouseArea {
            id: statusArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hover.openControlCenter()
        }
    }
}
