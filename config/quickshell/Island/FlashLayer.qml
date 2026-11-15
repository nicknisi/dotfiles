import QtQuick
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine

// FlashLayer.qml - a mode toggled: the island flashes a ringed status and
// settles back (island-modes 6.3, Island board "Mode flash").
//
//   ←8→ (( ☕ )) ←12→ Keep awake        ←22→
//                     On for 1 hour
//
// 52 high (radius 26), as wide as its words. The ring is 36 px with a 2 px
// ring inside: on, ring and the 16 px icon in `accent`; off, the ring
// `faint`, the icon `inkDim` and a slash across it (26 x 2, radius 1,
// `inkDim`, at -45 degrees). Title 13 / 500 `fg`, sub 12 `inkDim`, 1 apart.
// Shown for 1400 ms [GUESS], then back to what it interrupted.
//
// Triggers (the view): keep awake (Caffeine; "On for 1 hour" from
// Caffeine.durationLabel, "On until turned off", "Off") and Do not disturb
// (NotificationState.dnd; "On", "Off").
Layer {
    id: flash

    // "awake" | "dnd"
    property string mode: "awake"
    property bool isOn: false
    property string sub: ""

    readonly property string title: mode === "dnd" ? "Do not disturb" : "Keep awake"
    readonly property string icon: mode === "dnd" ? "moon" : "coffee"
    readonly property real hugWidth: 8 + 36 + 12 + Math.ceil(Math.max(titleText.implicitWidth, subText.implicitWidth)) + 22
    readonly property alias ring: ring
    readonly property alias slash: slash

    width: IslandMachine.size({ state: "flash" }, hugWidth)[0]
    height: 52

    Accessible.role: Accessible.AlertMessage
    Accessible.name: title + ", " + (sub !== "" ? sub : isOn ? "On" : "Off")

    Rectangle {
        id: ring
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: "transparent"
        border.width: 2
        border.color: flash.isOn ? Tokens.accent : Tokens.faint
        Icon {
            anchors.centerIn: parent
            name: flash.icon
            size: 16
            color: flash.isOn ? Tokens.accent : Tokens.inkDim
        }
        Rectangle {
            id: slash
            anchors.centerIn: parent
            visible: !flash.isOn
            width: 26
            height: 2
            radius: 1
            rotation: -45
            color: Tokens.inkDim
            antialiasing: true
        }
    }

    Column {
        anchors.left: ring.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            id: titleText
            text: flash.title
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Text {
            id: subText
            text: flash.sub !== "" ? flash.sub : flash.isOn ? "On" : "Off"
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }
}
