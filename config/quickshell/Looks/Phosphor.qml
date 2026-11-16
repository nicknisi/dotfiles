import QtQuick
import QtQuick.Effects
import qs
import qs.Kit
import qs.Island
import "../lib/LookModel.js" as LookModel
import "../lib/CrewModel.js" as CrewModel

// Phosphor.qml - the green-screen terminal (personal-looks 4.2, Looks board).
//
//   rest    ←14→[D][W][C]←18→10:45▮←18→[^_^] [O_O]! [-_-]z←14→
//   moment  ←16→> green phosphor, no mercy▮←16→          (the sign-off)
//
// The rest bar is the board's packed row (padding 14, gap 18), hugged by
// the island with no 360 floor; while something is live the live segment
// (Island/LiveSegment, in the ink) follows the clock. The pointer works as
// on the plain pill: a tab click activates its workspace, the wheel over
// the tabs steps through them, and the faces are the Crew zone (resting
// there opens the Crew panel, a click pins it).
//
// Monaspace Argon in the look's ink (the pack's accent, or fg where the
// accent does not reach 4.5 on `darker`: LookModel.ink), glowing 0 0 6 at
// .6 through one MultiEffect on the content. Tabs: padding 1 6, square; the
// focused one filled with the ink, its letter in the ground, the others a
// 1 px ring at .5. The block cursor (7 x 14) blinks 500 / 500, 5 after the
// clock and 4 after the tagline. The Crew as ASCII faces, gap 8: a needs
// face steps between 1 and the hail loop's low frame, .55, on the cursor's
// clock (the board's 800 ms four-frame loop, stepped on the one 500 ms
// clock so the island draws two frames a second), an asleep one is the ink
// at .6 (mixed, and the full ink where that misses 4.5: LookModel.ink).
// The body (Look.material: darker, 1 px ink ring, radius 4, 36 high, glow
// 0 0 14 at .35) is the island's.
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

    readonly property color inkColor: look.ink.text ?? Tokens.accent
    readonly property real hugWidth: look.cell === "rest" ? rest.hugWidth : moment.hugWidth
    readonly property int shownAgents: Math.min((look.agents || []).length, CrewModel.MAX_BOTS)
    readonly property alias blink: blink
    readonly property bool blinkOn: !blink.ticking || Math.floor(blink.elapsed / 500) % 2 === 0
    readonly property alias restRow: rest
    readonly property alias momentRow: moment
    // The Crew zone (the faces): the view's dwell opens the Crew panel here.
    readonly property Item crewZone: rest.faces
    readonly property bool crewHovered: look.cell === "rest" && rest.faces.visible && rest.faces.hovered

    CrewClock {
        id: blink
        step: 500
        running: look.animated && Motion.loops
    }

    // Everything glows but the focused tab's letter, which the board leaves
    // flat; one effect over the whole row is the cheap reading of that.
    Item {
        id: glowing
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Tokens.alpha(look.ink.glow ?? Tokens.accent, 0.6)
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 12
            shadowBlur: 0.5
        }

        Row {
            id: rest
            visible: look.cell === "rest"
            // The board's packed row, centred in the island (whose width
            // rounds this up to the step).
            x: Math.round((look.width - rest.width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            readonly property real hugWidth: 2 * 14 + Math.ceil(rest.implicitWidth)
            readonly property alias tabs: tabs
            readonly property alias faces: faces
            readonly property alias clockText: clockText
            readonly property alias cursor: cursor
            readonly property alias segment: segment

            Row {
                id: tabs
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                // The wheel steps through the tabs (WorkspaceOrder.wheel).
                WheelHandler {
                    onWheel: event => look.wheeled(event.angleDelta.y)
                }
                Repeater {
                    model: (look.workspaces || []).length
                    delegate: Rectangle {
                        id: tab
                        required property int index
                        readonly property var ws: look.workspaces[index] ?? ({})
                        readonly property bool focused: ws.focused === true
                        width: Math.ceil(letter.implicitWidth) + 12
                        height: Math.ceil(letter.implicitHeight) + 2
                        color: focused ? (look.ink.tabFill ?? look.inkColor) : "transparent"
                        border.width: focused ? 0 : 1
                        border.color: Tokens.alpha(look.inkColor, 0.5)
                        Accessible.role: Accessible.Button
                        Accessible.name: "Workspace " + (ws.name ?? "") + (focused ? ", focused" : "")
                        Accessible.onPressAction: look.activated(String(tab.ws.name ?? ""))
                        Text {
                            id: letter
                            anchors.centerIn: parent
                            text: String(parent.ws.name ?? "")
                            color: parent.focused ? (look.ink.tabText ?? Tokens.darker) : look.inkColor
                            font.family: "Monaspace Argon"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: look.activated(String(tab.ws.name ?? ""))
                        }
                    }
                }
            }

            // The clock, then the cursor 5 after it (the board's gap 2 and margin 3).
            Row {
                id: clockRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    id: clockText
                    anchors.verticalCenter: parent.verticalCenter
                    text: look.clock
                    color: look.inkColor
                    font.family: "Monaspace Argon"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Rectangle {
                    id: cursor
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 14
                    color: look.inkColor
                    opacity: look.blinkOn ? 1 : 0
                }
            }

            // What is live (recording, the mic, keep awake, DND), in the ink.
            LiveSegment {
                id: segment
                anchors.verticalCenter: parent.verticalCenter
                height: 36
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

            // The Crew: resting here opens the Crew panel, a click pins it.
            Item {
                id: faces
                anchors.verticalCenter: parent.verticalCenter
                visible: look.shownAgents > 0
                width: facesRow.implicitWidth
                height: facesRow.implicitHeight
                readonly property bool hovered: crewHover.hovered
                HoverHandler {
                    id: crewHover
                }
                Row {
                    id: facesRow
                    spacing: 8
                    Repeater {
                        model: look.shownAgents
                        delegate: Text {
                            required property int index
                            readonly property var agent: look.agents[index] ?? ({})
                            text: LookModel.face(agent.mood)
                            // Asleep: the ink at .6, mixed (LookModel: one fade, audited).
                            color: agent.mood === "asleep" ? (look.ink.asleep ?? look.inkColor) : look.inkColor
                            // Needs you: the board's hail loop low frame (.55), on the cursor's clock.
                            opacity: agent.mood === "needs" && !look.blinkOn ? 0.55 : 1
                            font.family: "Monaspace Argon"
                            font.pixelSize: 12
                            Accessible.role: Accessible.StaticText
                            Accessible.name: (agent.name ?? "") + ", " + (agent.state ?? "")
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

        Item {
            id: moment
            anchors.fill: parent
            visible: look.cell !== "rest"
            readonly property real hugWidth: 16 + Math.ceil(line.implicitWidth) + 4 + 7 + 16
            readonly property alias line: line

            Text {
                id: line
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 560)
                text: "> " + look.tagline
                color: look.inkColor
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.pixelSize: 13
            }
            Rectangle {
                x: line.x + line.width + 4
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 14
                color: look.inkColor
                opacity: look.blinkOn ? 1 : 0
            }
        }
    }
}
