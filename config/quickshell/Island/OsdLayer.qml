import QtQuick
import qs
import qs.Kit

// OsdLayer.qml - volume, brightness and the microphone as the island itself
// (island-modes 9.2, main-tokens 2.5.7, Main board `osd`, 340 x 44).
//
//   ←18→ 🔊 ←12→ [████████░░░░░░░░░░░░] ←12→  45 ←18→
//
// Icon 16 `fg` (vol / vol1 below half / volMute, sun for brightness, mic or
// micOff); the track 6 high, radius 3, `fillHigh`, its `accent` fill as wide
// as the value, moving on the effects spring; the value in Monaspace 12,
// right-aligned in 26. The mic has no quantity behind it, so it draws
// "Mic on" / "Mic off" in place of the track [GUESS, main-tokens 2.5.7].
//
// Each Interrupt message re-offers the state, so holding volume-up keeps it
// up (the view restarts the 1400 ms on every message). Data comes in as
// plain values: kind "volume" | "brightness" | "mic", value 0..1, muted.
Layer {
    id: osd

    property string kind: "volume"
    property real value: 0
    property bool muted: false

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property bool metered: kind !== "mic"
    readonly property string icon: {
        if (kind === "brightness") return "sun";
        if (kind === "mic") return muted ? "micOff" : "mic";
        if (muted || clamped === 0) return "volMute";
        return clamped < 0.5 ? "vol1" : "vol";
    }
    readonly property string valueText: String(Math.round(clamped * 100))
    readonly property alias track: track
    readonly property alias fill: fill

    width: 340
    height: 44

    Accessible.role: Accessible.ProgressBar
    Accessible.name: kind === "mic" ? (muted ? "Microphone off" : "Microphone on") : (kind === "brightness" ? "Brightness " : "Volume ") + valueText + "%"

    Icon {
        id: glyph
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        name: osd.icon
        size: 16
        color: osd.kind === "mic" && !osd.muted ? Tokens.accent : Tokens.fg
    }

    Rectangle {
        id: track
        visible: osd.metered
        anchors.left: glyph.right
        anchors.leftMargin: 12
        anchors.right: number.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Tokens.fillHigh
        Rectangle {
            id: fill
            height: 6
            radius: 3
            color: Tokens.accent
            width: Math.round(track.width * osd.clamped)
            Behavior on width {
                NumberAnimation {
                    duration: Motion.effects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spring
                }
            }
        }
    }

    Text {
        visible: !osd.metered
        anchors.left: glyph.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: osd.muted ? "Mic off" : "Mic on"
        color: Tokens.fg
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }

    Text {
        id: number
        visible: osd.metered
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        horizontalAlignment: Text.AlignRight
        text: osd.valueText
        color: Tokens.fg
        font.family: "Monaspace Argon"
        font.pixelSize: 12
    }
}
