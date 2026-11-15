import QtQuick
import qs

// Keycap.qml - a key name in a small `fillHigh` cap: Monaspace Argon 11,
// padding 2 6, radius 5. `small` is the footer and badge variant, padding 1 5,
// radius 4 (the power menu's letter badges also set fontSize 10 and ink inkDim).
Rectangle {
    id: root

    property string text: ""
    property bool small: false
    property color ink: Tokens.fg
    property int fontSize: 11
    property string fontFamily: "Monaspace Argon"

    readonly property int padX: small ? 5 : 6
    readonly property int padY: small ? 1 : 2

    implicitWidth: Math.ceil(label.implicitWidth) + 2 * padX
    implicitHeight: Math.ceil(label.implicitHeight) + 2 * padY
    radius: small ? 4 : 5
    color: Tokens.fillHigh
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        Accessible.ignored: true
    }
}
