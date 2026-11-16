import QtQuick
import qs
import qs.Kit
import qs.Island
import "../lib/LookModel.js" as LookModel
import "../lib/CrewModel.js" as CrewModel
import "../lib/Stardate.js" as Stardate

// Bridge.qml - LCARS, run by Riker (personal-looks 4.3, Looks board).
//
//   rest    (cap)(STARDATE 80869.7)(10:45)(W)(C)(D)(S)(AWAY TEAM 4      )(cap)
//   moment  (cap)(REX HAILING                        )(ON SCREEN)(cap)   (the hail)
//
// Segments 32 high with 4 px of the black body between them, Antonio 600 15
// uppercase at .6 px spacing. Fills from the board: caps `accent`, the
// stardate `cyan`, the focused letter `fg`, the others `blue`, the away team
// `magenta`; the hail `accent` and On screen `magentaBright`. The ink on each
// is black, or white where black does not reach 4.5 (LookModel.ink: the
// light packs' `fg`). The board's rest row has no clock time; OmniWM's
// Bridge clock showed one, so a time segment (`fg`) follows the stardate
// (personal-looks 4.3 [GUESS]). The last text segment stretches, so the row
// always fills the island. In the hail the cap and name step through the
// board's hail loop (900 ms: 1, .775, .55, .775, a frame every 225 ms, only
// while the hail is up), and On screen jumps to the agent.
//
// The pointer works as on the plain pill: a letter click activates its
// workspace, the wheel over the letters steps through them, and the away
// team is the Crew zone (resting there opens the Crew panel, a click pins
// it). While something is live the live segment sits on the black body
// after the time, in white or fg (LookModel.ink's live inks).
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

    readonly property var seg: look.ink.segments ?? ({})
    readonly property var inks: look.ink.inks ?? ({})
    readonly property string stardate: Fixture.data.stardate ?? Stardate.format(look.now)
    readonly property int attention: (look.agents || []).filter(a => a && a.attention).length
    readonly property real hugWidth: look.cell === "rest" ? rest.hugWidth : hail.hugWidth
    readonly property alias restRow: rest
    readonly property alias hailRow: hail
    readonly property Item crewZone: rest.away
    readonly property bool crewHovered: look.cell === "rest" && rest.away.crew && rest.away.hovered
    readonly property alias blink: blink
    // The board's hail loop: 900 ms in four steps, 1, .775, .55, .775.
    readonly property real hailOpacity: blink.ticking ? [1, 0.775, 0.55, 0.775][Math.floor(blink.elapsed / 225) % 4] : 1
    readonly property bool blinkOn: look.hailOpacity === 1

    CrewClock {
        id: blink
        step: 225
        running: look.animated && look.cell !== "rest" && Motion.loops
    }

    // One segment: its fill and ink come in, so the component needs nothing
    // from the file around it.
    component Segment: Rectangle {
        id: segment
        property string label: ""
        property color ink: "#000000"
        property real pad: 12
        property real fixed: -1
        readonly property real natural: segment.fixed >= 0 ? segment.fixed : Math.ceil(words.implicitWidth) + 2 * segment.pad
        width: segment.natural
        height: 32
        Accessible.role: Accessible.StaticText
        Accessible.name: segment.label
        Text {
            id: words
            visible: segment.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            x: segment.pad
            text: segment.label
            color: segment.ink
            font.family: "Antonio"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
            textFormat: Text.PlainText
        }
    }
    function fill(role: string): color {
        return look.seg[role] ?? Tokens.accent;
    }
    function inkOn(role: string): color {
        return look.inks[role] ?? "#000000";
    }

    Row {
        id: rest
        visible: look.cell === "rest"
        height: 32
        spacing: 4
        // Everything but the stretching away team at its own width (the
        // live segment, when something is live, with its gap).
        readonly property real fixedWidth: 36 + 4 + date.natural + 4 + time.natural + 4 + (segment.visible ? segment.width + 4 : 0) + letters.width + 4 + 4 + 24
        readonly property real hugWidth: Math.ceil(rest.fixedWidth + away.natural)
        readonly property alias date: date
        readonly property alias away: away
        readonly property alias letters: letters
        readonly property alias segment: segment

        Segment { fixed: 36; color: look.fill("cap"); topLeftRadius: 16; bottomLeftRadius: 16 }
        Segment { id: date; color: look.fill("stardate"); ink: look.inkOn("stardate"); label: "Stardate " + look.stardate }
        Segment { id: time; color: look.fill("clock"); ink: look.inkOn("clock"); label: look.clock; pad: 10 }
        // What is live (recording, the mic, keep awake, DND), on the black
        // body between the time and the letters.
        LiveSegment {
            id: segment
            height: 32
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
            id: letters
            spacing: 4
            // The wheel steps through the letters (WorkspaceOrder.wheel).
            WheelHandler {
                onWheel: event => look.wheeled(event.angleDelta.y)
            }
            Repeater {
                model: (look.workspaces || []).length
                delegate: Segment {
                    id: letterSegment
                    required property int index
                    readonly property var ws: look.workspaces[index] ?? ({})
                    readonly property string role: ws.focused === true ? "focused" : "other"
                    color: look.fill(role)
                    ink: look.inkOn(role)
                    label: String(ws.name ?? "")
                    pad: 10
                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + (ws.name ?? "") + (ws.focused === true ? ", focused" : "")
                    Accessible.onPressAction: look.activated(String(letterSegment.ws.name ?? ""))
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: look.activated(String(letterSegment.ws.name ?? ""))
                    }
                }
            }
        }
        // The away team is the Crew zone: resting on it opens the Crew
        // panel, a click pins it.
        Segment {
            id: away
            readonly property bool crew: (look.agents || []).length > 0
            readonly property bool hovered: crewHover.hovered
            color: look.fill("team")
            ink: look.inkOn("team")
            label: away.crew ? LookModel.awayTeam(look.total, look.attention) : ""
            width: Math.max(away.natural, look.width - rest.fixedWidth)
            Accessible.role: away.crew ? Accessible.Button : Accessible.StaticText
            Accessible.onPressAction: if (away.crew) look.pinCrew()
            HoverHandler {
                id: crewHover
                enabled: away.crew
            }
            MouseArea {
                anchors.fill: parent
                enabled: away.crew
                cursorShape: Qt.PointingHandCursor
                onClicked: look.pinCrew()
            }
        }
        Segment { fixed: 24; color: look.fill("cap"); topRightRadius: 16; bottomRightRadius: 16 }
    }

    Row {
        id: hail
        visible: look.cell !== "rest"
        height: 32
        spacing: 4
        readonly property var words: CrewModel.hail(look.hailAgent, look.hailOthers)
        readonly property real fixedWidth: 36 + 4 + 4 + screen.natural + 4 + 24
        readonly property real hugWidth: Math.ceil(hail.fixedWidth + name.natural)
        readonly property alias name: name
        readonly property alias screen: screen

        Segment {
            fixed: 36
            color: look.fill("hail")
            topLeftRadius: 16
            bottomLeftRadius: 16
            opacity: look.hailOpacity
        }
        Segment {
            id: name
            color: look.fill("hail")
            ink: look.inkOn("hail")
            label: (look.hailAgent?.name ?? "") + " hailing" + (look.hailOthers > 0 ? " · +" + look.hailOthers : "")
            width: Math.max(name.natural, look.width - hail.fixedWidth)
            opacity: look.hailOpacity
        }
        Segment {
            id: screen
            color: look.fill("screen")
            ink: look.inkOn("screen")
            label: "On screen"
            Accessible.role: Accessible.Button
            Accessible.name: hail.words.button
            Accessible.onPressAction: look.go()
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: look.go()
            }
        }
        Segment { fixed: 24; color: look.fill("screen"); topRightRadius: 16; bottomRightRadius: 16 }
    }
}
