import QtQuick
import qs
import qs.Kit

// HoverLayer.qml - the open island (island-modes 7, main-tokens 2.5.2,
// Main board `hover`, 720 x 136; Personal board's tagline sign-off).
//
//   ←18→ [eq] Neon Grid          10:45          [ wifi bt ts vol ▮ 25% ] ←18→
//             Night Rider   Saturday, November 14   ✦ Claude Code dotfiles ⑂ main +2
//             ⏮ ⏯ ⏭
//                       green phosphor, no mercy
//
// "Quiet at rest, rich on hover." Three columns 16 apart: media (250), the
// clock (the rest), status (250). Each zone is a door: the clock opens the
// calendar, the status pill the control center (the old Hud home until M6),
// and the Context line the window it describes ([GUESS] Main draws no button
// there; the Island board calls it a door).
//
// Media: the 64 px `raised` tile with four `accent` eq bars (the eq loop,
// still while paused), the title 13 / 500, the artist 12 `inkDim`, and three
// 28 px round buttons (prev and next `inkDim`, play/pause `fg`). Nothing
// playing [GUESS]: the bars lie still in `inkDim` and the title says so.
// Clock: Monaspace 40 / 500 on a 44 line, the date 12 `inkDim` below.
// Status: a 32 high `fillLow` pill (Wi-Fi, Bluetooth, Tailscale, volume,
// battery and its percent); off or disconnected icons go `inkDim`, a low
// battery `bad` [GUESS]. The Context line under it: the lane's icon (the
// sparkle breathes in `accent` while an agent works), who in `fg`, where in
// `inkDim`, the branch icon and "main +2" in Monaspace.
//
// The last row is the pack's tagline in Monaspace Radon italic 15 (Personal
// board: "The open island ends with it"). Main's 720 x 136 has no room drawn
// for it, so the columns sit higher (a 14 px top) and the tagline takes the
// bottom [GUESS, personal-looks 3.8].
//
// Hover is 720 wide, or the rest pill's width when that is wider (the view
// sizes it); the columns keep their places from each edge.
Layer {
    id: hover

    property string clock: ""
    property string date: ""
    // { title, artist, playing, canPrevious, canNext } or null when nothing plays.
    property var media: null
    // { wifi, bt, tailscale, muted, battery, charging, low }
    property var status: ({})
    // Context.lane: { kind, icon, working, who, where, detail }
    property var lane: ({})
    property string tagline: ""
    // Loops (eq, breathe) run only while this holds.
    property bool animated: true

    signal openCalendar
    signal openControlCenter
    signal openContext
    signal previous
    signal togglePlaying
    signal next
    signal pin

    readonly property bool playing: media?.playing === true
    readonly property alias clockButton: clockButton
    readonly property alias statusPill: statusPill
    readonly property alias contextLine: contextLine
    readonly property alias taglineText: taglineText
    readonly property alias mediaTile: tile
    readonly property alias contextIcon: contextIcon
    readonly property alias sparkleClock: sparkleClock

    // main-tokens 2.4: the eq loop's periods and phases, ms.
    readonly property var eqPeriods: [800, 930, 1060, 1190]
    readonly property var eqOffsets: [0, 230, 460, 690]

    width: 720
    height: 136

    // Empty hover space pins it, like the rest pill's button.
    MouseArea {
        anchors.fill: parent
        onClicked: hover.pin()
        Accessible.ignored: true
    }

    // The columns' row: centred when there is no tagline, else at the top.
    Item {
        id: main
        x: 18
        width: parent.width - 36
        height: 80
        y: taglineText.visible ? 14 : Math.round((hover.height - height) / 2)

        // ---- media (left, 250) ----
        Row {
            id: mediaZone
            width: 250
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                id: tile
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 64
                radius: 12
                color: Tokens.raised
                border.width: 1
                border.color: Tokens.hairline

                property real clock: 0
                NumberAnimation on clock {
                    running: hover.current && hover.playing && hover.animated && Motion.loops
                    from: 0
                    to: 3600
                    duration: 3600 * 1000
                    loops: Animation.Infinite
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    spacing: 3
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 26
                            radius: 2
                            color: hover.media ? Tokens.accent : Tokens.inkDim
                            transform: Scale {
                                origin.y: 26
                                // scaleY 0.3 -> 1 -> 0.3; held where it is while paused.
                                yScale: 0.3 + 0.7 * (0.5 - 0.5 * Math.cos(2 * Math.PI * (tile.clock * 1000 + hover.eqOffsets[index]) / hover.eqPeriods[index]))
                            }
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 250 - 64 - 12
                spacing: 4
                Text {
                    width: parent.width
                    text: hover.media?.title || "Nothing playing"
                    color: hover.media ? Tokens.fg : Tokens.inkDim
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: hover.media?.artist ?? ""
                    color: Tokens.inkDim
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
                Row {
                    visible: hover.media !== null
                    x: -7
                    topPadding: 2
                    spacing: 2
                    Repeater {
                        model: [
                            { icon: "prev", name: "Previous track", color: "dim", enabled: hover.media?.canPrevious !== false },
                            { icon: hover.playing ? "pause" : "play", name: hover.playing ? "Pause" : "Play", color: "fg", enabled: true },
                            { icon: "next", name: "Next track", color: "dim", enabled: hover.media?.canNext !== false }
                        ]
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: 28
                            height: 28
                            radius: 14
                            opacity: modelData.enabled ? 1 : 0.4
                            color: transport.containsMouse && modelData.enabled ? Tokens.fillLow : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.name
                            Accessible.onPressAction: hover.transport(index)
                            Icon {
                                anchors.centerIn: parent
                                name: parent.modelData.icon
                                size: 14
                                solid: true
                                color: parent.modelData.color === "fg" ? Tokens.fg : Tokens.inkDim
                            }
                            MouseArea {
                                id: transport
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.modelData.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hover.transport(parent.index)
                            }
                        }
                    }
                }
            }
        }

        // ---- clock (centre): a door to the calendar ----
        Rectangle {
            id: clockButton
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
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

        // ---- status (right, 250): the pill, then the Context line ----
        Column {
            id: statusZone
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 250
            spacing: 12

            Rectangle {
                id: statusPill
                anchors.right: parent.right
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
                        name: hover.status.wifi === false ? "wifiOff" : "wifi"
                        size: 14
                        color: hover.status.wifi === false ? Tokens.inkDim : Tokens.fg
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: hover.status.bt === false ? "btOff" : "bt"
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
                        name: hover.status.muted === true ? "volMute" : "vol"
                        size: 14
                        color: hover.status.muted === true ? Tokens.inkDim : Tokens.fg
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: hover.status.charging === true ? "batteryCharging" : hover.status.low === true ? "batteryLow" : "battery"
                            size: 14
                            color: hover.status.low === true && hover.status.charging !== true ? Tokens.bad : Tokens.fg
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

            // The Context line: a door to the window it describes.
            Item {
                id: contextLine
                anchors.right: parent.right
                visible: (hover.lane?.who ?? "") !== ""
                width: Math.min(contextRow.implicitWidth, 250)
                height: Math.max(16, contextRow.implicitHeight)
                Accessible.role: Accessible.Button
                Accessible.name: "Go to " + (hover.lane?.who ?? "")
                Accessible.onPressAction: hover.openContext()

                Row {
                    id: contextRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon {
                        id: contextIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: name !== ""
                        name: hover.lane?.icon ?? ""
                        size: 14
                        color: hover.lane?.working === true ? Tokens.accent : Tokens.inkDim
                        // Stepped, as on the rest pill (M3 review): 1.6 s on a 250 ms clock.
                        opacity: sparkleClock.running ? Motion.breath(sparkleClock.elapsed, 1600, 0.45) : 1
                        CrewClock {
                            id: sparkleClock
                            step: 250
                            running: hover.lane?.working === true && hover.current && hover.animated && Motion.loops
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hover.lane?.who ?? ""
                        color: Tokens.fg
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        width: Math.min(implicitWidth, 90)
                        elide: Text.ElideRight
                        text: hover.lane?.where ?? ""
                        color: Tokens.inkDim
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (hover.lane?.detail ?? "") !== ""
                        name: "branch"
                        size: 14
                        color: Tokens.inkDim
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: hover.lane?.detail ?? ""
                        color: Tokens.inkDim
                        textFormat: Text.PlainText
                        font.family: "Monaspace Argon"
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: hover.openContext()
                }
            }
        }
    }

    // ---- the sign-off: the pack's tagline (Personal board) ----
    Text {
        id: taglineText
        visible: text !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: main.y + main.height + 6
        width: Math.min(implicitWidth, parent.width - 36)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: hover.tagline
        textFormat: Text.PlainText
        color: Tokens.fg
        font.family: "Monaspace Radon"
        font.italic: true
        font.pixelSize: 15
        Accessible.role: Accessible.StaticText
        Accessible.name: hover.tagline
    }

    function transport(i: int): void {
        if (i === 0) hover.previous();
        else if (i === 1) hover.togglePlaying();
        else hover.next();
    }
}
