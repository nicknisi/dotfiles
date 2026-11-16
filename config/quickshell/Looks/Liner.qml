import QtQuick
import QtQuick.Shapes
import qs
import qs.Kit
import qs.Island

// Liner.qml - the handwritten zine (personal-looks 4.5, Looks board).
//
//   rest    ←20→ W  C  D  S ←24→10:45←24→ [CREW ×4] ←20→
//                      ~~~
//   moment  ←20→ green phosphor, no mercy ←20→                  (the sign-off)
//
// Monaspace Radon italic in `fg` on the plain material (surface, 1 px
// hairline, 40 high, radius 20, no shadow: the board draws none). Letters 16,
// gap 14, uppercase; the focused one at full ink with an `accent` scribble
// under it, the others the board's fg at .6, mixed over the surface and drawn
// at full opacity (or `inkDim` where that would not reach 4.5: LookModel.ink;
// one fade, so the audit tests what is on screen). The scribble is the board's path in an
// 18 x 6 box, 4 left of the letter, under its box: the [GUESS] reading of
// a visible stroke stretched to the box, 1.6 wide as OmniWM drew it. Clock
// 17. The stamp: "CREW ×{total}" (or "{n} NEED YOU" while agents wait, as
// OmniWM's stamp did) in Monaspace Argon 11 upright, .88 spacing, padding
// 2 8, a 2 px ring, radius 3, rotated -6 degrees, in `bad` (the palette's
// `red` is green or blue on some packs: 4.5 [NEEDS CHECK] settled on `bad`,
// with `fg` where `bad` falls short).
//
// The rest bar is the board's packed row (padding 20, gap 24), hugged with
// no 360 floor; the live segment, while something is live, follows the
// clock. A letter click activates its workspace, the wheel over the letters
// steps through them, and the stamp is the Crew zone.
//
// The moment line is the sign-off: the tagline, Radon italic 15 `inkDim`. The
// board's sticky note ("Standup · 12m") needs a calendar source that milhouse
// does not have, so it is left out (PLAN M9: no placeholder).
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

    readonly property int attention: (look.agents || []).filter(a => a && a.attention).length
    readonly property string stampText: look.attention > 0 ? look.attention + " NEED YOU" : "CREW ×" + look.total
    readonly property real hugWidth: look.cell === "rest" ? rest.hugWidth : moment.hugWidth
    readonly property alias restRow: rest
    readonly property alias momentRow: moment
    readonly property Item crewZone: rest.stamp
    readonly property bool crewHovered: look.cell === "rest" && rest.stamp.visible && rest.stamp.hovered

    Row {
        id: rest
        visible: look.cell === "rest"
        // The board's packed row, centred in the island.
        x: Math.round((look.width - rest.width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24
        readonly property real hugWidth: 2 * 20 + Math.ceil(rest.implicitWidth)
        readonly property alias letters: letters
        readonly property alias stamp: stamp
        readonly property alias clockText: clockText
        readonly property alias segment: segment

        Row {
            id: letters
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            // The wheel steps through the letters (WorkspaceOrder.wheel).
            WheelHandler {
                onWheel: event => look.wheeled(event.angleDelta.y)
            }
            Repeater {
                model: (look.workspaces || []).length
                delegate: Text {
                    id: letter
                    required property int index
                    readonly property var ws: look.workspaces[index] ?? ({})
                    readonly property bool focused: ws.focused === true
                    text: String(ws.name ?? "").toUpperCase()
                    // One fade: the faded ink is already the board's fg at .6
                    // over the surface (or inkDim), drawn at full opacity.
                    color: focused ? (look.ink.text ?? Tokens.fg) : (look.ink.faded ?? Tokens.inkDim)
                    font.family: "Monaspace Radon"
                    font.italic: true
                    font.pixelSize: 16
                    textFormat: Text.PlainText
                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + (ws.name ?? "") + (focused ? ", focused" : "")
                    Accessible.onPressAction: look.activated(String(letter.ws.name ?? ""))

                    Shape {
                        visible: letter.focused
                        x: -4
                        y: letter.height
                        width: 18
                        height: 6
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: look.ink.accent ?? Tokens.accent
                            strokeWidth: 1.6
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            // The board's M1 4 Q 6 0 11 3 T 21 3 T 31 2 T 39 3 (viewBox 40 x 6), x scaled to 18.
                            PathSvg { path: "M 0.45 4 Q 2.7 0 4.95 3 T 9.45 3 T 13.95 2 T 17.55 3" }
                        }
                    }
                    MouseArea {
                        // A little wider than the italic letter, so a narrow one is easy to hit.
                        x: -4
                        width: letter.width + 8
                        height: letter.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: look.activated(String(letter.ws.name ?? ""))
                    }
                }
            }
        }

        Text {
            id: clockText
            anchors.verticalCenter: parent.verticalCenter
            text: look.clock
            color: look.ink.text ?? Tokens.fg
            font.family: "Monaspace Radon"
            font.italic: true
            font.pixelSize: 17
            textFormat: Text.PlainText
        }

        // What is live (recording, the mic, keep awake, DND).
        LiveSegment {
            id: segment
            anchors.verticalCenter: parent.verticalCenter
            height: 40
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

        // The stamp is the Crew zone: resting on it opens the Crew panel, a
        // click pins it.
        Rectangle {
            id: stamp
            readonly property bool hovered: crewHover.hovered
            visible: (look.agents || []).length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(stampWords.implicitWidth) + 16
            height: Math.ceil(stampWords.implicitHeight) + 4
            radius: 3
            rotation: -6
            antialiasing: true
            color: "transparent"
            border.width: 2
            border.color: look.ink.stamp ?? Tokens.bad
            Accessible.role: Accessible.Button
            Accessible.name: look.stampText
            Accessible.onPressAction: look.pinCrew()
            HoverHandler {
                id: crewHover
            }
            Text {
                id: stampWords
                anchors.centerIn: parent
                text: look.stampText
                color: look.ink.stamp ?? Tokens.bad
                font.family: "Monaspace Argon"
                font.pixelSize: 11
                font.letterSpacing: 0.88
                textFormat: Text.PlainText
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: look.pinCrew()
            }
        }
    }

    Item {
        id: moment
        anchors.fill: parent
        visible: look.cell !== "rest"
        readonly property real hugWidth: 20 + Math.ceil(line.width) + 20
        readonly property alias line: line
        Text {
            id: line
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 560)
            text: look.tagline
            color: look.ink.dim ?? Tokens.inkDim
            elide: Text.ElideRight
            font.family: "Monaspace Radon"
            font.italic: true
            font.pixelSize: 15
            textFormat: Text.PlainText
        }
    }
}
