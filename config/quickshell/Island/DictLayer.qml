import QtQuick
import qs
import qs.Kit

// DictLayer.qml - dictation from the voxtype daemon, as the island itself
// (island-modes 9.3, main-tokens 2.5.8, Main board `dict`, 360 x 48).
//
//   ←16→ 🎤 ←12→ ▮▯▮▮▯▮… (20 bars) ←12→ Listening ←12→ 0:03 ←12→ (x) ←8→
//
// Mic 16 `accent`; the wave, 24 high, 20 bars of 3 x 22, radius 2, `fg`, 3
// apart; "Listening" 12 `inkDim`; the elapsed time in Monaspace 12; Stop, a
// 32 px `fillHigh` circle with an x ("Stop dictation").
//
// The bars follow the daemon's loudness (VoiceSession.history, the newest on
// the right) when it has any, as VoxtypeOsd's wave does; until then, or
// without levels, they run the board's wave loop (scaleY 0.2 -> 1 -> 0.2 about
// the centre, each bar on its own period and phase). While the daemon
// finishes the transcript the wave lies flat and the label says "Finishing"
// [GUESS: the board draws no transcribing phase].
//
// In island mode this replaces VoxtypeOsd's bottom popup (PLAN M3). Data comes
// in as plain values; Stop asks the view, which runs `voxtype record stop`.
Layer {
    id: dict

    // "listening" | "transcribing"
    property string phase: "listening"
    property string elapsed: "0:00"
    // Loudness samples 0..1, newest last (VoiceSession.history).
    property var levels: []
    // The wave loop runs only while this holds.
    property bool animated: true

    signal stop

    readonly property bool listening: phase === "listening"
    readonly property string label: listening ? "Listening" : "Finishing"
    readonly property alias stopButton: stopButton
    readonly property alias wave: wave

    // main-tokens 2.4: the wave loop's periods and phases, ms.
    readonly property var periods: [620, 757, 894, 1031, 688, 825, 962, 1099, 756, 893, 1030, 687, 824, 961, 1098, 755, 892, 1029, 686, 823]
    readonly property var offsets: [0, 89, 178, 267, 356, 445, 534, 623, 12, 101, 190, 279, 368, 457, 546, 635, 24, 113, 202, 291]

    width: 360
    height: 48

    Accessible.role: Accessible.Grouping
    Accessible.name: (listening ? "Listening" : "Finishing the transcript") + ", " + elapsed

    // One clock for every bar: seconds since the loop started.
    property real clock: 0
    NumberAnimation on clock {
        running: dict.current && dict.animated && dict.listening && dict.levels.length === 0 && Motion.loops
        from: 0
        to: 3600
        duration: 3600 * 1000
        loops: Animation.Infinite
    }

    function barScale(i: int): real {
        if (!listening) return 0.2;
        const n = levels.length;
        if (n > 0) {
            // The newest 20 samples, oldest on the left; missing ones lie flat.
            const k = n - 20 + i;
            return 0.2 + 0.8 * Math.max(0, Math.min(1, k >= 0 ? Number(levels[k]) || 0 : 0));
        }
        const p = (clock * 1000 + offsets[i]) / periods[i];
        return 0.2 + 0.8 * (0.5 - 0.5 * Math.cos(2 * Math.PI * p));
    }

    Icon {
        id: mic
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        name: "mic"
        size: 16
        color: Tokens.accent
    }

    Row {
        id: wave
        anchors.left: mic.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        spacing: 3
        Repeater {
            model: 20
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 22
                radius: 2
                color: Tokens.fg
                transform: Scale {
                    origin.y: 11
                    yScale: dict.barScale(index)
                }
            }
        }
    }

    Rectangle {
        id: stopButton
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        radius: 16
        color: stopArea.pressed ? Tokens.fillLow : Tokens.fillHigh
        Accessible.role: Accessible.Button
        Accessible.name: "Stop dictation"
        Accessible.onPressAction: dict.stop()
        Icon {
            anchors.centerIn: parent
            name: "x"
            size: 14
            color: Tokens.fg
        }
        MouseArea {
            id: stopArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: dict.stop()
        }
    }

    Text {
        id: time
        anchors.right: stopButton.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: dict.elapsed
        color: Tokens.fg
        font.family: "Monaspace Argon"
        font.pixelSize: 12
    }

    Text {
        anchors.right: time.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: dict.label
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
}
