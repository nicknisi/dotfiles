import QtQuick
import qs
import qs.Kit
import "../lib/CrewModel.js" as CrewModel
import "../lib/IslandMachine.js" as IslandMachine

// VibesCard.qml - the last hail handled (personal-looks 3.7, Personal board:
// "The easter egg from your old sketchybar pill").
//
//   ←22→ bot ←10→ vibes: immaculate ←22→
//
// 44 high (radius 22), as wide as its line. An awake bot in `accent` bobbing
// at 800 ms, and the line in Monaspace Radon italic 16 `fg`, breathing .65 to
// 1 over 1.6 s. The view shows it for 4 s. Reduced motion holds both still,
// the words at full opacity.
Layer {
    id: card

    property real dpr: 1
    // The host's gate on the bot's loop (the session not idle).
    property bool animated: true
    property string line: "vibes: immaculate"

    readonly property real hugWidth: 22 + 16 + 10 + Math.ceil(words.implicitWidth) + 22

    // The island's width (see HailCard): the line centres in what rounding adds.
    width: IslandMachine.size({ state: "vibes" }, hugWidth)[0]
    height: 44

    Accessible.role: Accessible.StaticText
    Accessible.name: card.line

    CrewBot {
        id: bot
        x: 22 + Math.floor((card.width - card.hugWidth) / 2)
        anchors.verticalCenter: parent.verticalCenter
        mood: "working"
        tint: Tokens.accent
        period: CrewModel.VIBES_PERIOD
        dpr: card.dpr
        animated: card.current && card.animated
    }

    Text {
        id: words
        anchors.left: bot.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: card.line
        color: Tokens.fg
        font.family: "Monaspace Radon"
        font.italic: true
        font.pixelSize: 16
        opacity: breathe.running ? breathe.level : 1
        Accessible.ignored: true

        QtObject {
            id: breathe
            property real level: 0.65
            readonly property bool running: loop.running
        }
        SequentialAnimation {
            id: loop
            running: card.current && Motion.loops
            loops: Animation.Infinite
            NumberAnimation { target: breathe; property: "level"; from: 0.65; to: 1; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: breathe; property: "level"; from: 1; to: 0.65; duration: 800; easing.type: Easing.InOutSine }
        }
    }
}
