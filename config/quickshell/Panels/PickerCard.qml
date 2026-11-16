import QtQuick
import qs

// PickerCard.qml - one card in the theme or wallpaper grid (PLAN M7,
// launcher-pickers 7.1 and 7.2, Pickers board).
//
//   ┌ padding 6 ───────────┐
//   │ [ image, radius 10 ] │   PickerThumb, cropped to fill
//   │ ● ● ●                │   theme cards: bg, fg, accent, 14 px, a faint ring
//   │ tokyo-night          │   12 / 500 (a wallpaper's file name: 12)
//   │ dark                 │   11 `inkDim`: the mode, Current or Previewing
//   └──────────────────────┘   radius 16
//
// States (inner rings, like the board's inset box-shadows):
//   idle      nothing; a wallpaper card has a 1 px `hairline` ring
//   current   2 px `faint`
//   focused   2 px `accent` on `accentTint`, whether or not it is current
// The fill and the rings cross-fade by opacity over Motion.effects on the
// spring, never with a colour Behavior: Tokens already animates a theme
// change, and a second animation would chase it every frame.
//
// hovered() when the pointer moves on it once `armed` (the panel's gate: a
// pointer parked under a freshly opened grid does not steal focus);
// clicked() on a press.
Item {
    id: card

    property string image: ""
    property size thumbSize: Qt.size(0, 0)
    property real imageHeight: 80
    // The image's corner radius: the board's 10; the Profile picture
    // sheet's circles (FaceGrid) pass half the image's width.
    property real thumbRadius: 10
    property string title: ""
    property int titleWeight: Font.Medium
    property string note: ""
    // Palette dots, as colours: a theme's bg, fg and accent; none for a wallpaper.
    property var dots: []
    property bool focused: false
    property bool current: false
    property bool idleRing: false
    property bool armed: true
    property string accessibleName: title

    signal hovered
    signal clicked

    readonly property alias thumb: thumb
    readonly property alias titleText: titleText
    readonly property alias noteText: noteText

    Accessible.role: Accessible.Button
    Accessible.name: card.accessibleName
    Accessible.onPressAction: card.clicked()

    component Fade: NumberAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: 16
        color: Tokens.accentTint
        opacity: card.focused ? 1 : 0
        Behavior on opacity { Fade {} }
    }
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.width: 1
        border.color: Tokens.hairline
        visible: opacity > 0
        opacity: card.idleRing && !card.focused && !card.current ? 1 : 0
        Behavior on opacity { Fade {} }
    }
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.width: 2
        border.color: Tokens.faint
        visible: opacity > 0
        opacity: card.current && !card.focused ? 1 : 0
        Behavior on opacity { Fade {} }
    }
    Rectangle {
        id: ring
        objectName: "pickerCardRing"
        anchors.fill: parent
        radius: 16
        color: "transparent"
        border.width: 2
        border.color: Tokens.accent
        visible: opacity > 0
        opacity: card.focused ? 1 : 0
        Behavior on opacity { Fade {} }
    }

    PickerThumb {
        id: thumb
        x: 6
        y: 6
        width: card.width - 12
        height: card.imageHeight
        radius: card.thumbRadius
        source: card.image
        sourceSize: card.thumbSize
    }

    Row {
        id: dotRow
        x: 8
        y: thumb.y + thumb.height + 8
        spacing: 4
        visible: card.dots.length > 0
        Repeater {
            model: card.dots.length
            delegate: Rectangle {
                required property int index
                width: 14
                height: 14
                radius: 7
                color: card.dots[index] ?? "transparent"
                border.width: 1
                border.color: Tokens.faint
            }
        }
    }

    Text {
        id: titleText
        x: 8
        y: dotRow.visible ? dotRow.y + 14 + 8 : thumb.y + thumb.height + 8
        width: card.width - 16
        height: 15
        verticalAlignment: Text.AlignVCenter
        text: card.title
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Tokens.fg
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: card.titleWeight
    }
    Text {
        id: noteText
        x: 8
        y: titleText.y + titleText.height + 1
        width: card.width - 16
        height: 14
        visible: card.note !== ""
        verticalAlignment: Text.AlignVCenter
        text: card.note
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: if (card.armed) card.hovered()
        onEntered: if (card.armed) card.hovered()
        onClicked: card.clicked()
    }
}
