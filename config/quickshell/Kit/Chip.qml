import QtQuick
import qs

// Chip.qml - a fully round label: the launcher's "All sources", count badges,
// status tags. Display only; PillButton is the pressable one.
//
// tone   fill         ink
// quiet  fillLow      inkDim    (default, "All sources": 12 px, padding 4 10)
// strong fillHigh     fg        (count badges: mono, fontSize 11, padding 1 6)
// accent accent       onAccent
// tint   accentTint   fg
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string tone: "quiet"
    property bool mono: false
    property int fontSize: 12
    property int padX: 10
    property int padY: 4
    property color ink: tone === "accent" ? Tokens.onAccent : tone === "quiet" ? Tokens.inkDim : Tokens.fg

    implicitWidth: Math.ceil(row.implicitWidth) + 2 * padX
    implicitHeight: Math.ceil(row.implicitHeight) + 2 * padY
    radius: height / 2
    color: tone === "accent" ? Tokens.accent
         : tone === "strong" ? Tokens.fillHigh
         : tone === "tint" ? Tokens.accentTint
         : Tokens.fillLow
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: 14
            color: root.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.ink
            font.family: root.mono ? "Monaspace Argon" : "Adwaita Sans"
            font.pixelSize: root.fontSize
            Accessible.ignored: true
        }
    }
}
