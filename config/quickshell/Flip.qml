// Flip.qml - one line of text that swaps for another in place.
//
// The capsule answers where you touch it. Point at the clock and the time
// becomes the date; point at the battery and the percentage becomes what is
// left. Both strings live in the same box at the same size, so nothing reflows
// and nothing is covered, which is exactly what the tooltips were getting
// wrong: a panel that floats over your work to tell you what you are already
// looking at.
import QtQuick

Item {
    id: flip

    property string front: ""
    property string back: ""
    property bool flipped: false
    property color color: Theme.fg
    property int pixelSize: Theme.fontSize
    property bool bold: false

    // An empty back has nothing to say, so the front simply stays put.
    readonly property bool turned: flip.flipped && flip.back !== ""

    implicitWidth: Math.max(frontLine.implicitWidth, backLine.implicitWidth)
    implicitHeight: Math.max(frontLine.implicitHeight, backLine.implicitHeight)

    component Line: Text {
        width: flip.width
        height: flip.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        font.family: Theme.font
        font.pixelSize: flip.pixelSize
        font.bold: flip.bold
        color: flip.color
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }
    }

    // The two lines pass each other rather than dissolving into each other, so
    // the swap has a direction and reads as one label turning over.
    Line {
        id: frontLine
        text: flip.front
        y: flip.turned ? -7 : 0
        opacity: flip.turned ? 0 : 1
    }

    Line {
        id: backLine
        text: flip.back
        y: flip.turned ? 0 : 7
        opacity: flip.turned ? 1 : 0
    }
}
