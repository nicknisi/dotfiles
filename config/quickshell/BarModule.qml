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
    property real cornerRadius: Theme.controlRadius
    // Content runs left to right, or top to bottom when the capsule is stood
    // on its side and a glyph has to sit above its number.
    property bool stacked: false
    default property alias content: inner.data
    signal scrolled(real delta)

    implicitWidth: Math.max(32, inner.implicitWidth + 16)
    // Tall enough for whatever is stacked in it. Fixed at 24 this let the
    // battery's glyph-over-number spill out of the button and under the endcap
    // when the capsule stood on its side.
    implicitHeight: Math.max(24, inner.implicitHeight + topPadding + bottomPadding)
    padding: 8
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    opacity: enabled ? 1 : 0.35
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) mod.clicked(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) mod.clicked(); }

    // Hover and press are colour-only feedback. Size changes made modules
    // lurch past the capsule edge in compact and vertical modes.
    background: Rectangle {
        radius: mod.cornerRadius
        color: mod.highlighted ? Theme.glowFill : (mod.hovered ? Theme.raised : "transparent")
        border.width: mod.visualFocus ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    contentItem: GridLayout {
        id: inner
        flow: mod.stacked ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 6
        columnSpacing: 6
        // Children centre on the button's full height now that nothing is
        // stealing it, so glyphs and numbers share one optical centre line.
        WheelHandler {
            onWheel: event => mod.scrolled(event.angleDelta.y)
        }
    }
}
