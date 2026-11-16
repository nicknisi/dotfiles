import QtQuick
import qs
import qs.Kit

// LiveSegment.qml - what is live right now, as part of the rest pill
// (island-modes 6.1, 6.2, Island board "Live indicators").
//
//   10:45 ←12→ | ←12→ ● 0:42 ←12→ [ Stop ]      a screen recording
//   10:45 ←12→ | ←10→ 🎤 Zoom ←10→ ☕ 52m ←10→ 🌙   mic, keep awake, DND
//
// "Recording, microphone use and keep-awake grow the pill instead of adding
// chips." The board draws each pill with only the clock and the indicator;
// here the whole rest pill stays and this segment sits right of the clock
// ([GUESS] in 6), so the pill widens on the spatial spring (RestLayer's hug
// width) while the segment fades in on the effects spring, after the stagger
// (Kit/Layer's enter). Going, it fades out over exitFade, linear, and keeps
// its width until the fade ends, so the pill closes in behind it.
//
// Recording: an 8 px `bad` dot breathing over 1.4 s (dotOpacity, from
// RestLayer's stepped clock), the elapsed time in Monaspace (m:ss) and a
// Stop button (26 high, `fillHigh`): Capture.stop().
// Microphone: mic 14 `accent` and the app's name (the first, then "+N" for
// more [GUESS]). Keep awake: coffee 14 `fg` and the time left ("52m"), the
// icon alone while it lasts until turned off [GUESS]. Do not disturb: moon 14
// `inkDim` [GUESS: no board draws it; PLAN M3 lists DND with the live
// indicators].
//
// Hidden (no width) when nothing is live. Data comes in as plain values
// (IslandView reads Capture, Audio, Caffeine and NotificationState).
//
// A personal look (M9) draws the same segment in its own bar, in its inks
// (`inks`, lib/LookModel.js live(): text, dim, accent, dot, divider, button,
// buttonPressed, buttonInk, ring, radius); null is the plain pill's tokens.
Item {
    id: segment

    property bool recording: false
    property string elapsed: ""
    // App names holding the microphone, first one shown.
    property var mic: []
    property bool awake: false
    // "52m", or "" while keep awake has no end.
    property string awakeLeft: ""
    property bool dnd: false
    // The recording dot's opacity: RestLayer breathes it on a stepped clock.
    property real dotOpacity: 1
    // A look's inks (LookModel live()), or null for the plain pill's.
    property var inks: null

    signal stop

    readonly property bool live: recording || mic.length > 0 || awake || dnd
    // Live, or still fading out: the segment keeps its width until then.
    property bool shown: false
    readonly property bool fading: fadeIn.running || fadeOut.running
    readonly property alias stopButton: stopButton
    readonly property alias dot: dot
    readonly property alias micIcon: micIcon
    readonly property alias micLabel: micLabel
    readonly property alias awakeIcon: awakeIcon
    readonly property alias awakeLabel: awakeLabel
    readonly property string micText: mic.length === 0 ? "" : mic[0] + (mic.length > 1 ? " +" + (mic.length - 1) : "")
    // What the rows draw: the inputs while something is live, the last live
    // ones while the segment fades out, so it leaves as it was.
    readonly property var inputs: ({ recording: recording, elapsed: elapsed, micText: micText, awake: awake, awakeLeft: awakeLeft, dnd: dnd })
    property var drawn: inputs
    // From the inputs, not `live`: its binding may not have caught up here.
    onInputsChanged: if (recording || mic.length > 0 || awake || dnd) drawn = inputs

    visible: shown
    opacity: 0
    implicitWidth: shown ? row.implicitWidth : 0
    implicitHeight: 38
    width: implicitWidth
    height: implicitHeight

    onLiveChanged: {
        if (live) {
            fadeOut.stop();
            shown = true;
            fadeIn.restart();
        } else if (shown) {
            fadeIn.stop();
            fadeOut.restart();
        }
    }
    // Live when created (a login mid-recording): shown at once, as a Layer is.
    Component.onCompleted: if (live) {
        shown = true;
        opacity = 1;
    }
    SequentialAnimation {
        id: fadeIn
        PauseAnimation { duration: Motion.stagger }
        NumberAnimation {
            target: segment
            property: "opacity"
            to: 1
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation {
            target: segment
            property: "opacity"
            to: 0
            duration: Motion.exitFade
            easing.type: Easing.Linear
        }
        PropertyAction { target: segment; property: "shown"; value: false }
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: [recording ? "Recording " + elapsed : "", micText !== "" ? "Microphone in use by " + micText : "", awake ? "Keep awake on" + (awakeLeft !== "" ? ", " + awakeLeft + " left" : "") : "", dnd ? "Do not disturb on" : ""].filter(s => s !== "").join(", ")

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 16
            color: segment.inks?.divider ?? Tokens.hairline
        }

        // ---- recording (6.1): dot, elapsed, Stop; 12 apart ----
        Row {
            id: recordingRow
            anchors.verticalCenter: parent.verticalCenter
            visible: segment.drawn.recording
            spacing: 12
            leftPadding: 2
            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: segment.inks?.dot ?? Tokens.bad
                opacity: segment.dotOpacity
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: segment.drawn.elapsed
                color: segment.inks?.text ?? Tokens.fg
                font.family: "Monaspace Argon"
                font.pixelSize: 12
            }
            Rectangle {
                id: stopButton
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(stopLabel.implicitWidth) + 20
                height: 26
                radius: segment.inks?.radius ?? 13
                color: segment.inks ? (stopArea.pressed ? segment.inks.buttonPressed : segment.inks.button) : stopArea.pressed ? Tokens.fillLow : Tokens.fillHigh
                // A Stop filled with a look's ground gets a ring in its ink.
                border.width: segment.inks && segment.inks.ring ? 1 : 0
                border.color: segment.inks?.ring || "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: "Stop recording"
                Accessible.onPressAction: segment.stop()
                Text {
                    id: stopLabel
                    anchors.centerIn: parent
                    text: "Stop"
                    color: segment.inks?.buttonInk ?? Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: stopArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: segment.stop()
                }
            }
        }

        // ---- microphone in use (6.2) ----
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: segment.drawn.micText !== ""
            spacing: 10
            Icon {
                id: micIcon
                anchors.verticalCenter: parent.verticalCenter
                name: "mic"
                size: 14
                color: segment.inks?.accent ?? Tokens.accent
            }
            Text {
                id: micLabel
                anchors.verticalCenter: parent.verticalCenter
                // Whole pixels, so the coffee icon after it is not drawn between them.
                width: Math.min(Math.ceil(implicitWidth), 120)
                text: segment.drawn.micText
                color: segment.inks?.dim ?? Tokens.inkDim
                elide: Text.ElideRight
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        // ---- keep awake (6.2) ----
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: segment.drawn.awake
            spacing: 10
            Icon {
                id: awakeIcon
                anchors.verticalCenter: parent.verticalCenter
                name: "coffee"
                size: 14
                color: segment.inks?.text ?? Tokens.fg
            }
            Text {
                id: awakeLabel
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: segment.drawn.awakeLeft
                color: segment.inks?.dim ?? Tokens.inkDim
                font.family: "Monaspace Argon"
                font.pixelSize: 12
            }
        }

        // ---- do not disturb [GUESS] ----
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: segment.drawn.dnd
            name: "moon"
            size: 14
            color: segment.inks?.dim ?? Tokens.inkDim
        }
    }
}
