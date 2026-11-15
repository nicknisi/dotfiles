import QtQuick
import qs
import qs.Kit

// MediaPill.qml - what is playing, on the lock screen (PLAN M8, Lock board):
// bottom left, 24 from the edges.
//
//   ( [▮▮▮]  Title            ⏮  (▶)  ⏭ )   52 high, radius 26, surface,
//            Artist                          hairline, the one shadow;
//                                            padding 0 8, gap 12
//
// Art: 36 x 36, radius 10, `raised`, three accent bars 3 x 16 (radius 2,
// gap 2) standing on its bottom 10 px in. While playing they move on the
// board's eq periods (800 / 950 / 1100 ms, offsets 0 / 300 / 600), stepped on
// a 100 ms CrewClock as CcMedia's do, so the lock draws ten frames a second
// while music plays and none when it is paused or motion is reduced.
// Prev and next: 32 circles, inkDim 14. Play: a 36 circle in `fg` with the
// glyph in `bg` (control-lock 4.5; the board's onAccent reads the same on
// the dark packs and vanishes on latte's fg).
//
// `media` is lib/CcData.js's mediaCard() shape; hidden when nothing plays
// (present false). Presses come out as previous / toggle / next for the host.
//
// QtQuick only (qmltestrunner loads it).
Surface {
    id: pill

    property var media: null
    // The host's gate on the eq loop (the lock surface is showing).
    property bool animate: true

    readonly property bool present: pill.media?.present === true
    readonly property bool playing: pill.present && pill.media?.playing === true
    readonly property alias eqClock: eqClock
    readonly property alias playButton: play

    signal previous
    signal toggle
    signal next

    readonly property var eqPeriods: [800, 950, 1100]
    readonly property var eqOffsets: [0, 300, 600]

    visible: pill.present
    height: 52
    width: Math.ceil(row.implicitWidth + 16)
    radius: 26

    Accessible.role: Accessible.Grouping
    Accessible.name: "Now playing"

    CrewClock {
        id: eqClock
        step: 100
        running: pill.playing && pill.animate && pill.visible && Motion.loops
    }

    Row {
        id: row
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            id: art
            width: 36
            height: 36
            radius: 10
            color: Tokens.raised
            anchors.verticalCenter: parent.verticalCenter
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 3
                        height: 16
                        radius: 2
                        color: Tokens.accent
                        anchors.bottom: parent.bottom
                        // Paused: three still heights.
                        transform: Scale {
                            origin.y: 16
                            yScale: eqClock.ticking ? 0.3 + 0.7 * (0.5 - 0.5 * Math.cos(2 * Math.PI * (eqClock.elapsed + pill.eqOffsets[index]) / pill.eqPeriods[index])) : [0.6, 1, 0.45][index]
                        }
                    }
                }
            }
        }

        // Title and artist, 6 px clear of the buttons (the board's padding-right).
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: texts.width + 6
            height: texts.height
            Column {
                id: texts
                width: Math.min(Math.max(titleText.implicitWidth, artistText.implicitWidth), 220)
                spacing: 1
                Text {
                    id: titleText
                    width: parent.width
                    text: String(pill.media?.title ?? "")
                    color: Tokens.fg
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Text {
                    id: artistText
                    width: parent.width
                    visible: text !== ""
                    text: String(pill.media?.artist ?? "")
                    color: Tokens.inkDim
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
        }

        LockButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            iconName: "prev"
            iconSize: 14
            ink: Tokens.inkDim
            label: "Previous track"
            enabled: pill.media?.canPrevious !== false
            onActivated: pill.previous()
        }
        LockButton {
            id: play
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            iconName: pill.playing ? "pause" : "play"
            iconSize: 14
            fill: Tokens.fg
            ink: Tokens.bg
            label: pill.playing ? "Pause" : "Play"
            onActivated: pill.toggle()
        }
        LockButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            iconName: "next"
            iconSize: 14
            ink: Tokens.inkDim
            label: "Next track"
            enabled: pill.media?.canNext !== false
            onActivated: pill.next()
        }
    }
}
