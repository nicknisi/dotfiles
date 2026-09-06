// Stable, keyboard-accessible capsule and HUD button.
//
// `text` is the accessible name and nothing else. It used to raise a tooltip,
// which floated a panel over whatever you were working on to name a glyph you
// were already pointing at. Modules that have something more to say now say it
// in their own box; see Flip.qml.
//
// Vertical padding is pinned to zero. `padding` on a Control insets all four
// edges, so a caller asking for a 24px-tall button with the default 8px padding
// left its content 8px to live in, and a 14px line of text drew from the top of
// that crushed box and hung out the bottom. That is why the clock, the volume
// glyph and the battery percent all sat low in the capsule. Only horizontal
// padding shapes a pill, so it is the only one a caller gets to set.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: mod

    property bool highlighted: false
    property real cornerRadius: height / 2
    default property alias content: inner.data
    signal scrolled(real delta)

    implicitWidth: Math.max(32, inner.implicitWidth + 16)
    implicitHeight: 24
    padding: 8
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    opacity: enabled ? 1 : 0.35

    // Hover is a colour, not a size. Growing 7% with an overshoot made the wide
    // modules lurch past the capsule's edge and snap back, which reads as a
    // rendering fault rather than as feedback. Only a press moves anything, and
    // only a little.
    scale: down ? 0.94 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic }
    }

    background: Rectangle {
        radius: mod.cornerRadius
        color: mod.highlighted ? Theme.glowFill : (mod.hovered ? Theme.raised : "transparent")
        border.width: mod.visualFocus ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on radius { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
    }

    contentItem: RowLayout {
        id: inner
        spacing: 6
        // Children centre on the button's full height now that nothing is
        // stealing it, so glyphs and numbers share one optical centre line.
        WheelHandler {
            onWheel: event => mod.scrolled(event.angleDelta.y)
        }
    }
}
