import QtQuick
import qs
import qs.Kit
import qs.Island
import "../lib/LookModel.js" as LookModel
import "../lib/CrewModel.js" as CrewModel

// Arcade.qml - the 8-bit cabinet HUD (personal-looks 4.4, Looks board).
//
//   rest    ←16→Stage D←18→1UP 10:45←18→♥♡♡♡←18→👾 👾 👾 👾←16→
//   moment  ←16→HI 4 ←28→ Crew x4 ←28→ Player 3 needs you←16→   (the hail)
//
// Press Start 2P 10 on `darker` (the body: square, a 2 px `fg` ring, 38
// high), the board's mixed case. Stage shows the focused letter only. 1UP
// blinks 500 / 500 in `bad`, 8 before the clock. Hearts: four 7 x 6 sprites
// at 14 x 12, gap 3, ceil(percent / 25) of them filled (`bad`), the rest
// `fillHigh`; none without a battery. Invaders: one per agent (eight at
// most), 11 x 8 sprites 12 high, gap 6, `fg` working, `accent` needing you,
// `inkDim` asleep; the awake ones march 3 px every 600 ms, the sleepers stay.
// Static 2 x 2 stars from the board's formula, thinned to the island
// (LookModel.stars), sit under it all. The moment line is the hail: the
// spend high score, the crew count, and "Player n needs you" blinking in
// `bad`; a click on it jumps. Every ink falls back to `fg` where the board's
// does not reach its contrast on the pack (LookModel.ink).
//
// The rest bar is the board's packed row (padding 16, gap 18), hugged with
// no 360 floor; the live segment, while something is live, follows the
// clock. The wheel over Stage steps the workspaces; the invaders are the
// Crew zone (resting there opens the Crew panel, a click pins it).
Item {
    id: look

    property string cell: "rest"
    property var ink: ({})
    property var workspaces: []
    property string clock: ""
    property date now: new Date()
    property var agents: []
    property int total: 0
    property var spend: null
    property var battery: null
    property var media: null
    property string tagline: ""
    property var hailAgent: null
    property int hailOthers: 0
    property real dpr: 1
    property bool animated: true
    property var live: ({})
    property real dotOpacity: 1

    signal go
    signal activated(string name)
    signal pinCrew
    signal wheeled(real delta)
    signal stopRecording

    readonly property var invader: ["..#.....#..", "...#...#...", "..#######..", ".##.###.##.", "###########", "#.#######.#", "#.#.....#.#", "...##.##..."]
    readonly property var heart: [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
    readonly property int hearts: LookModel.hearts(look.battery)
    readonly property string stage: {
        const f = (look.workspaces || []).find(w => w && w.focused);
        return f ? "Stage " + f.name : "";
    }
    readonly property var status: LookModel.arcadeStatus(look.agents, look.total, look.spend)
    readonly property int shownAgents: Math.min((look.agents || []).length, CrewModel.MAX_BOTS)
    readonly property real hugWidth: look.cell === "rest" ? rest.hugWidth : line.hugWidth
    readonly property alias restRow: rest
    readonly property alias statusRow: line
    readonly property Item crewZone: rest.invaders
    readonly property bool crewHovered: look.cell === "rest" && rest.invaders.visible && rest.invaders.hovered
    readonly property alias blink: blink
    readonly property alias march: march
    readonly property bool blinkOn: !blink.ticking || Math.floor(blink.elapsed / 500) % 2 === 0
    readonly property real marchOffset: march.ticking && Math.floor(march.elapsed / 600) % 2 === 1 ? 3 : 0
    readonly property var starList: LookModel.stars(look.width, look.height)

    CrewClock {
        id: blink
        step: 500
        running: look.animated && Motion.loops
    }
    CrewClock {
        id: march
        step: 600
        running: look.animated && Motion.loops && look.cell === "rest" && (look.agents || []).some(a => a && a.mood !== "asleep")
    }

    Repeater {
        model: look.starList.length
        delegate: Rectangle {
            required property int index
            readonly property var star: look.starList[index] ?? ({ x: 0, y: 0, alpha: 0 })
            x: star.x
            y: star.y
            width: 2
            height: 2
            color: look.ink.star ?? Tokens.fg
            opacity: star.alpha
        }
    }

    component Words: Text {
        font.family: "Press Start 2P"
        font.pixelSize: 10
        textFormat: Text.PlainText
    }

    Row {
        id: rest
        visible: look.cell === "rest"
        // The board's packed row, centred in the island.
        x: Math.round((look.width - rest.width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        readonly property real hugWidth: 2 * 16 + Math.ceil(rest.implicitWidth)
        readonly property alias stageText: stageText
        readonly property alias heartsRow: heartsRow
        readonly property alias invaders: invaders
        readonly property alias segment: segment

        // Stage shows the focused letter only; the wheel over it steps the
        // workspaces (WorkspaceOrder.wheel), as over the plain pill's letters.
        Words {
            id: stageText
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: look.stage
            color: look.ink.accent ?? Tokens.accent
            WheelHandler {
                onWheel: event => look.wheeled(event.angleDelta.y)
            }
        }

        Row {
            id: centre
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Words {
                text: "1UP"
                color: look.ink.bad ?? Tokens.bad
                opacity: look.blinkOn ? 1 : 0
            }
            Words {
                text: look.clock
                color: look.ink.text ?? Tokens.fg
            }
        }

        // What is live (recording, the mic, keep awake, DND), in the HUD's inks.
        LiveSegment {
            id: segment
            anchors.verticalCenter: parent.verticalCenter
            height: 38
            inks: look.ink.live ?? null
            recording: look.live?.recording === true
            elapsed: look.live?.elapsed ?? ""
            mic: look.live?.mic ?? []
            awake: look.live?.awake === true
            awakeLeft: look.live?.awakeLeft ?? ""
            dnd: look.live?.dnd === true
            dotOpacity: look.dotOpacity
            onStop: look.stopRecording()
        }

        Row {
            id: heartsRow
            visible: look.hearts >= 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Accessible.role: Accessible.StaticText
            Accessible.name: "Battery " + look.hearts + " of 4"
            Repeater {
                model: 4
                delegate: PixelSprite {
                    required property int index
                    rows: look.heart
                    size: 12
                    dpr: look.dpr
                    color: index < look.hearts ? (look.ink.heart ?? Tokens.bad) : (look.ink.heartEmpty ?? Tokens.fillHigh)
                }
            }
        }

        // The Crew: resting here opens the Crew panel, a click pins it.
        Item {
            id: invaders
            visible: look.shownAgents > 0
            anchors.verticalCenter: parent.verticalCenter
            // Room for the march (3 px), so the zone does not move under the pointer.
            width: invaderRow.implicitWidth + 3
            height: invaderRow.implicitHeight
            readonly property bool hovered: crewHover.hovered
            HoverHandler {
                id: crewHover
            }
            Row {
                id: invaderRow
                spacing: 6
                Repeater {
                    model: look.shownAgents
                    delegate: Item {
                        required property int index
                        readonly property var agent: look.agents[index] ?? ({})
                        width: sprite.width
                        height: sprite.height
                        Accessible.role: Accessible.Graphic
                        Accessible.name: (agent.name ?? "") + ", " + (agent.state ?? "")
                        PixelSprite {
                            id: sprite
                            x: parent.agent.mood === "asleep" ? 0 : sprite.snap(look.marchOffset, look.dpr)
                            rows: look.invader
                            size: 12
                            dpr: look.dpr
                            color: parent.agent.mood === "needs" ? (look.ink.invaderNeeds ?? Tokens.accent) : parent.agent.mood === "asleep" ? (look.ink.invaderAsleep ?? Tokens.inkDim) : (look.ink.invader ?? Tokens.fg)
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: look.pinCrew()
                Accessible.role: Accessible.Button
                Accessible.name: "The Crew"
                Accessible.onPressAction: look.pinCrew()
            }
        }
    }

    Row {
        id: line
        visible: look.cell !== "rest"
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 28
        readonly property real hugWidth: 16 + Math.ceil(line.implicitWidth) + 16
        Words {
            visible: text !== ""
            text: look.status.score
            color: look.ink.text ?? Tokens.fg
        }
        Words {
            text: look.status.crew
            color: look.ink.accent ?? Tokens.accent
        }
        Words {
            id: needs
            visible: text !== ""
            text: look.status.needs
            color: look.ink.bad ?? Tokens.bad
            opacity: look.blinkOn ? 1 : 0
        }
    }
    // The line is the hail: a click on it jumps to the player.
    MouseArea {
        anchors.fill: line
        visible: look.cell !== "rest"
        cursorShape: Qt.PointingHandCursor
        onClicked: look.go()
        Accessible.role: Accessible.Button
        Accessible.name: look.status.needs !== "" ? look.status.needs : look.status.crew
        Accessible.onPressAction: look.go()
    }
}
