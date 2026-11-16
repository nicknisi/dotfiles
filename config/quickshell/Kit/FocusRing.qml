import QtQuick
import qs

// FocusRing.qml - the keyboard focus ring: a 2 px `accent` outline 2 px
// outside its target, following the target's corner radius (the mocks'
// `outline: 2px solid accent; outline-offset: 2px`).
//
// Kit controls never take focus from a click, only from Tab or from a panel
// that calls forceActiveFocus() when it opens by key, so activeFocus already
// means keyboard focus and the ring never flashes under the pointer.
//
// Put it inside the control (the default target is the parent) or beside it
// with `target` set. It draws outside the target, so a clipping parent hides it.
Rectangle {
    id: root

    property Item target: parent
    property real gap: 2
    property real thickness: 2
    property real targetRadius: target && typeof target.radius === "number" ? target.radius : 0
    property bool show: target !== null && target.activeFocus

    anchors.fill: target
    anchors.margins: -(gap + thickness)
    radius: targetRadius > 0 ? targetRadius + gap + thickness : 0
    color: "transparent"
    border.width: thickness
    border.color: Tokens.accent
    visible: show
    z: 1000
    Accessible.ignored: true
}
