import QtQuick
import qs
import qs.Kit

// CcMedia.qml - the control center's now-playing card (control-lock 2.4,
// Main board `cc`).
//
//   ←14→ ┌────────┐ ←14→ Now playing                 fill x 148, radius 14
//        │ ▮▮▮▮   │      Neon Grid           15 / 500, 6 below
//        │        │      Night Rider         12 `inkDim`, 2 below
//        └────────┘      ═══════════─────    h4 `fillHigh`, fill `fg`
//        120 x 120       1:42          4:31  Monaspace 11 `inkDim`, 5 below
//                           ‹  (▶)  ›        30 / 34 / 30, 10 apart, 4 below
//
// The art well (`fillHigh`, radius 12) holds four `accent` bars, 7 x 48,
// radius 3, 5 apart, 32 off the bottom, each on the eq loop (scaleY 0.3 to 1
// and back, periods 800 / 930 / 1060 / 1190 ms, offsets 0 / 230 / 460 / 690).
// The loop is read off a stepped Kit/CrewClock (100 ms) rather than a smooth
// animation: the island body is a ClippingRectangle, and a smooth loop would
// redraw it at the display's rate for as long as music plays. It holds where
// it is while paused (frozen, not reset) and runs only while `animated`.
//
// The play button is `fg` with its icon in `bg` [DEVIATION, control-lock 2.4:
// the board's `onAccent` lands at 2.89:1 on rose-pine's fg].
//
// media: CcData.mediaCard(...): { present, title, artist, playing, progress,
// elapsed, total, canPrevious, canNext, canSeek, length }.
Rectangle {
    id: card

    property var media: ({ present: false, title: "", artist: "", playing: false, progress: 0, elapsed: "", total: "", canPrevious: false, canNext: false, canSeek: false, length: 0 })
    property bool animated: true

    signal previous
    signal togglePlaying
    signal next
    // A seek on the track, as a fraction of the length.
    signal seek(real fraction)
    // The wheel on the card: the next player (Media.selectNext) [GUESS].
    signal cycle

    readonly property alias playButton: playButton
    readonly property alias previousButton: previousButton
    readonly property alias nextButton: nextButton
    readonly property alias art: art
    readonly property alias eqClock: eqClock
    readonly property alias titleText: titleText
    readonly property bool playing: media?.playing === true

    readonly property var eqPeriods: [800, 930, 1060, 1190]
    readonly property var eqOffsets: [0, 230, 460, 690]

    implicitWidth: 360
    implicitHeight: 148
    radius: 14
    color: Tokens.raised
    border.width: 1
    border.color: Tokens.hairline

    Accessible.role: Accessible.Grouping
    Accessible.name: media?.present ? "Now playing, " + media.title : "Nothing playing"

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => card.cycle()
    }

    // Paused is frozen, not reset: CrewClock zeroes `elapsed` when it stops,
    // so a pause drops the step to 0 (no ticks) and leaves it running.
    CrewClock {
        id: eqClock
        step: card.playing ? 100 : 0
        running: card.animated && Motion.loops && card.media?.present === true
    }

    Rectangle {
        id: art
        x: 14
        y: 14
        width: 120
        height: 120
        radius: 12
        color: Tokens.fillHigh
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            spacing: 5
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: 7
                    height: 48
                    radius: 3
                    color: Tokens.accent
                    transform: Scale {
                        origin.y: 48
                        yScale: card.media?.present ? 0.3 + 0.7 * (0.5 - 0.5 * Math.cos(2 * Math.PI * (eqClock.elapsed + card.eqOffsets[index]) / card.eqPeriods[index])) : 0.3
                    }
                }
            }
        }
    }

    Item {
        id: info
        x: art.x + art.width + 14
        y: 14
        width: card.width - x - 14
        height: card.height - 28

        Text {
            id: caption
            text: card.media?.present ? "Now playing" : "Nothing playing"
            color: Tokens.inkDim
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
        Text {
            id: titleText
            y: caption.height + 6
            width: parent.width
            text: card.media?.title ?? ""
            color: Tokens.fg
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.Medium
        }
        Text {
            y: titleText.y + titleText.height + 2
            width: parent.width
            text: card.media?.artist ?? ""
            color: Tokens.inkDim
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }

        // From the bottom up: transport 34, 4 above it the times, 5 above
        // those the track.
        Row {
            id: transport
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10
            Round {
                id: previousButton
                size: 30
                iconSize: 11
                iconName: "prev"
                enabled: card.media?.canPrevious === true
                label: "Previous track"
                onActivated: card.previous()
            }
            Round {
                id: playButton
                size: 34
                fill: Tokens.fg
                iconName: card.playing ? "pause" : "play"
                // bg on fg, never onAccent (see above).
                ink: Tokens.bg
                enabled: card.media?.present === true
                label: card.playing ? "Pause" : "Play"
                onActivated: card.togglePlaying()
            }
            Round {
                id: nextButton
                size: 30
                iconSize: 11
                iconName: "next"
                enabled: card.media?.canNext === true
                label: "Next track"
                onActivated: card.next()
            }
        }
        Item {
            id: times
            anchors.bottom: transport.top
            anchors.bottomMargin: 4
            width: parent.width
            height: 14
            visible: (card.media?.total ?? "") !== ""
            Text {
                text: card.media?.elapsed ?? ""
                color: Tokens.inkDim
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                text: card.media?.total ?? ""
                color: Tokens.inkDim
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.pixelSize: 11
            }
        }
        Rectangle {
            id: track
            anchors.bottom: times.top
            anchors.bottomMargin: 5
            width: parent.width
            height: 4
            radius: 2
            color: Tokens.fillHigh
            Rectangle {
                height: 4
                radius: 2
                width: parent.width * Math.max(0, Math.min(1, Number(card.media?.progress) || 0))
                color: Tokens.fg
            }
            // No handle drawn: a press on the track seeks when the player can [GUESS].
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                enabled: card.media?.canSeek === true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => card.seek(Math.max(0, Math.min(1, mouse.x / Math.max(1, width))))
            }
        }
    }

    component Round: Rectangle {
        id: round
        property int size: 30
        // Lucide's skip-back / skip-forward span 18 of 24 units where the
        // board's span 14, so prev and next draw at 11 for the board's 8 x 10
        // glyph (M6 review); play and pause keep 14.
        property real iconSize: 14
        property string iconName: ""
        property color ink: Tokens.inkDim
        property color fill: "transparent"
        property string label: ""
        signal activated
        width: size
        height: size
        radius: size / 2
        color: round.fill !== Qt.color("transparent") ? round.fill : roundArea.containsMouse ? Tokens.fillLow : "transparent"
        opacity: enabled ? 1 : 0.4
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: round.activated()
        Keys.onPressed: event => {
            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                round.activated();
                event.accepted = true;
            }
        }
        Icon {
            anchors.centerIn: parent
            name: round.iconName
            size: round.iconSize
            color: round.ink
        }
        MouseArea {
            id: roundArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: round.activated()
        }
        FocusRing {}
    }
}
