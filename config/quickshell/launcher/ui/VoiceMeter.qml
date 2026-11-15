import QtQuick
import qs

// VoiceMeter.qml - the launcher header while dictating (launcher-pickers 5.4,
// Main board): 28 bars, 3 wide and 20 tall, radius 2, gap 3, in `fg`.
//
// Bar i takes the i-th newest loudness sample, newest at the right, scaled
// clamp(.2 + .8 * sample, .2, 1). The board's per-bar sine loop is
// decorative; the bars here follow the voice session's `history` instead
// (VoiceSession appends a sample about every 33 ms while listening), so a
// silent room draws a flat line and nothing redraws between samples.
Item {
    id: root

    property var history: []
    property int bars: 28

    implicitWidth: bars * 3 + (bars - 1) * 3
    implicitHeight: 22

    function sample(i) {
        const h = root.history || [];
        const at = h.length - root.bars + i;
        const v = at >= 0 && at < h.length ? Number(h[at]) || 0 : 0;
        return Math.max(0.2, Math.min(1, 0.2 + 0.8 * v));
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater {
            model: root.bars
            Rectangle {
                required property int index
                width: 3
                height: 20
                radius: 2
                color: Tokens.fg
                anchors.verticalCenter: parent.verticalCenter
                transform: Scale {
                    origin.y: 10
                    yScale: root.sample(index)
                }
            }
        }
    }
}
