import QtQuick
import qs
import qs.Kit
import "../lib/CrewModel.js" as CrewModel
import "../lib/IslandMachine.js" as IslandMachine

// HailCard.qml - an agent hailing you: the island opens on its own
// (personal-looks 3.6, Personal board "Hailing").
//
//   ←10→( ◯bot )←12→ Pi needs you                    ←22→ [ Go to pane ] ←8→
//                    Waiting for approval in tmux · dotfiles
//
// 52 high (radius 26 on the island), as wide as its words. The ring is 36 px
// with a 2 px `accent` border inside, the waving bot hopping in it. Title
// 13 / 500 `fg`, subtitle 12 `inkDim`; " · +N more" when others wait too.
// The button is "Go to pane" for tmux agents and "Go to window" otherwise,
// 32 high, `fillHigh`.
//
// The view owns the lifetime: a 5 s peek, held while the pointer rests on it
// (closed when it leaves), pinned by a click, dismissed by Go, Esc (once
// clicked, so it has the keyboard), an outside click or the attention
// clearing. The ring's lone bot runs its own clock: the card is short-lived.
//
// In a look with no hail of its own (Phosphor, Liner Notes, Outrun: M9), the
// card keeps its layout and takes the look's type and inks (`skin`, from
// lib/LookModel.js skin()); null is the plain island's.
Layer {
    id: card

    // The CrewModel record hailing, or null.
    property var agent: null
    // How many others also need you.
    property int others: 0
    property real dpr: 1
    // The host's gate on the bot's loop (the session not idle).
    property bool animated: true
    // { font, italic, upper, spacing, scale, ink, dim, accent, button, buttonInk }, or null.
    property var skin: null

    readonly property string family: card.skin?.font ?? "Adwaita Sans"
    readonly property real scale: card.skin?.scale ?? 1

    signal go
    signal pin

    readonly property var words: CrewModel.hail(card.agent, card.others)
    // The text column may not push the island past this.
    readonly property real maxText: 420
    readonly property real textWidth: Math.min(card.maxText, Math.max(title.implicitWidth, subtitle.implicitWidth))
    readonly property real hugWidth: 10 + 36 + 12 + Math.ceil(card.textWidth) + 22 + button.width + 8
    readonly property alias ring: ring
    readonly property alias button: button

    // The island's width (hugWidth rounded up like the body), so everything
    // inside starts on a whole device pixel and the button keeps its 8 px.
    width: IslandMachine.size({ state: "hail" }, hugWidth)[0]
    height: 52

    Accessible.role: Accessible.AlertMessage
    Accessible.name: card.words.title
    Accessible.description: card.words.subtitle

    MouseArea {
        anchors.fill: parent
        onClicked: card.pin()
        Accessible.ignored: true
    }

    Rectangle {
        id: ring
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: "transparent"
        border.width: 2
        border.color: card.skin?.accent ?? Tokens.accent
        CrewBot {
            anchors.centerIn: parent
            mood: "needs"
            tint: card.skin?.accent ?? Tokens.accent
            // The card is the moment: the board's hop, without the rest pill's pause.
            frames: CrewModel.HOP
            period: CrewModel.HOP_PERIOD
            dpr: card.dpr
            animated: card.current && card.animated
        }
    }

    Column {
        anchors.left: ring.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: card.textWidth
        spacing: 1
        Text {
            id: title
            width: parent.width
            text: card.words.title
            color: card.skin?.ink ?? Tokens.fg
            elide: Text.ElideRight
            font.family: card.family
            font.italic: card.skin?.italic === true
            font.capitalization: card.skin?.upper === true ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: card.skin?.spacing ?? 0
            font.pixelSize: Math.round(13 * card.scale)
            font.weight: Font.Medium
        }
        Text {
            id: subtitle
            width: parent.width
            text: card.words.subtitle
            color: card.skin?.dim ?? Tokens.inkDim
            elide: Text.ElideRight
            font.family: card.family
            font.italic: card.skin?.italic === true
            font.capitalization: card.skin?.upper === true ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: card.skin?.spacing ?? 0
            font.pixelSize: Math.round(12 * card.scale)
        }
    }

    Rectangle {
        id: button
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(label.implicitWidth) + 28
        height: 32
        radius: 16
        // Held down: a step toward its ink, in a look's skin as in the plain card.
        color: card.skin ? (press.pressed ? (card.skin.buttonPressed ?? card.skin.button) : card.skin.button) : press.pressed ? Tokens.fillLow : Tokens.fillHigh
        border.width: card.skin && card.skin.button === card.skin.ground ? 1 : 0
        border.color: card.skin?.buttonInk ?? Tokens.fg
        Accessible.role: Accessible.Button
        Accessible.name: card.words.button
        Accessible.onPressAction: card.go()
        Text {
            id: label
            anchors.centerIn: parent
            text: card.words.button
            color: card.skin?.buttonInk ?? Tokens.fg
            font.family: card.family
            font.capitalization: card.skin?.upper === true ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: card.skin?.spacing ?? 0
            font.pixelSize: Math.round(12 * card.scale)
        }
        MouseArea {
            id: press
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.go()
        }
    }
}
