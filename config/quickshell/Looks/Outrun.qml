import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs
import qs.Kit
import qs.Island

// Outrun.qml - neon tubes (personal-looks 4.6, Looks board).
//
//   rest    ←6→( W C D S )←10→( 10:45 )←10→( bot bot bot )←6→
//   moment  ←18→ ▶ Neon Grid  Night Rider ←18→                (now playing)
//
// The body is `bg` with no hairline and the second shadow (0 10 28
// `shadow2`), 40 high, radius 20. Three tubes, 26 high, radius 14, a 1.5 px
// ring and a 0 0 10 glow in their hue: the letters and the bots in `cyan`
// (glow at .55), the clock in `magenta` (.6). Letters Monaspace Argon 12,
// gap 10, unfocused `inkDim` (or `inkMid`, then `fg`, where it does not reach
// 4.5 on `bg`), the focused one `fg` with a cyan glow. Clock 13/500 `fg`.
// Bots 16 (the board's 14 snaps to 16 at 1.5), gap 6: working `fg`, needs
// `cyan` hopping, asleep `inkDim` (graphics: 3, `fg` where they fall short).
//
// The rest bar is the board's packed row (padding 6, gap 10), hugged with
// no 360 floor; the live segment, while something is live, follows the
// clock tube. A letter click activates its workspace, the wheel over the
// letters' tube steps through them, and the Crew's tube is the Crew zone.
//
// The moment line is now playing, peeked when a new track starts (the body:
// `bg`, a 1.5 px `magenta` ring, glow 0 0 12 at .6): the play triangle 12 in
// `cyan`, the title `fg`, the artist in the dim ink, Argon 12. Nothing playing,
// no line: the view never offers the moment then.
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

    readonly property real hugWidth: look.cell === "rest" ? rest.hugWidth : playing.hugWidth
    readonly property alias restRow: rest
    readonly property alias nowPlaying: playing
    readonly property Item crewZone: rest.crewTube
    readonly property bool crewHovered: look.cell === "rest" && rest.crewTube.visible && rest.crewTube.hovered

    // One tube: its hue and glow come in (the component reads nothing else).
    component Tube: Item {
        id: tube
        property color hue: "#00ffff"
        property real glowAlpha: 0.55
        property color fill: "#000000"
        property real padX: 12
        default property alias content: inner.data
        signal tapped
        implicitWidth: inner.implicitWidth + 2 * tube.padX
        implicitHeight: 26
        width: implicitWidth
        height: implicitHeight
        RectangularShadow {
            anchors.fill: parent
            radius: 14
            blur: 10
            spread: 0
            color: Qt.rgba(tube.hue.r, tube.hue.g, tube.hue.b, tube.glowAlpha)
        }
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: tube.fill
            border.width: 1.5
            border.color: tube.hue
            antialiasing: true
        }
        // The pointer over the whole tube, its padding included.
        property bool tappable: false
        readonly property bool hovered: tubeHover.hovered
        signal wheeled(real delta)
        HoverHandler {
            id: tubeHover
        }
        WheelHandler {
            onWheel: event => tube.wheeled(event.angleDelta.y)
        }
        // Under the content, so a letter or a bot takes its own click.
        MouseArea {
            anchors.fill: parent
            enabled: tube.tappable
            cursorShape: tube.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tube.tapped()
        }
        Row {
            id: inner
            x: tube.padX
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
        }
    }

    Row {
        id: rest
        visible: look.cell === "rest"
        // The board's packed row, centred in the island.
        x: Math.round((look.width - rest.width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        readonly property real hugWidth: 2 * 6 + Math.ceil(rest.implicitWidth)
        readonly property alias letterTube: letterTube
        readonly property alias clockTube: clockTube
        readonly property alias crewTube: crewTube
        readonly property alias segment: segment

        Tube {
            id: letterTube
            anchors.verticalCenter: parent.verticalCenter
            hue: look.ink.cyan ?? Tokens.cyan
            fill: look.ink.ground ?? Tokens.bg
            // The wheel steps through the letters (WorkspaceOrder.wheel).
            onWheeled: delta => look.wheeled(delta)
            Repeater {
                model: (look.workspaces || []).length
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property var ws: look.workspaces[index] ?? ({})
                    readonly property bool focused: ws.focused === true
                    anchors.verticalCenter: parent.verticalCenter
                    width: letter.implicitWidth
                    height: letter.implicitHeight
                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + (ws.name ?? "") + (focused ? ", focused" : "")
                    Accessible.onPressAction: look.activated(String(cell.ws.name ?? ""))
                    Text {
                        id: letter
                        text: String(parent.ws.name ?? "")
                        color: parent.focused ? (look.ink.text ?? Tokens.fg) : (look.ink.dim ?? Tokens.inkDim)
                        font.family: "Monaspace Argon"
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                        // The focused letter glows cyan (0 0 8 and 0 0 2).
                        layer.enabled: parent.focused
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: look.ink.cyan ?? Tokens.cyan
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            blurMax: 8
                            shadowBlur: 0.6
                        }
                    }
                    MouseArea {
                        // Half the gap either side, the tube's height.
                        x: -5
                        y: (cell.height - 26) / 2
                        width: cell.width + 10
                        height: 26
                        cursorShape: Qt.PointingHandCursor
                        onClicked: look.activated(String(cell.ws.name ?? ""))
                    }
                }
            }
        }

        Tube {
            id: clockTube
            anchors.verticalCenter: parent.verticalCenter
            padX: 14
            hue: look.ink.magenta ?? Tokens.magenta
            glowAlpha: 0.6
            fill: look.ink.ground ?? Tokens.bg
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: look.clock
                color: look.ink.text ?? Tokens.fg
                font.family: "Monaspace Argon"
                font.pixelSize: 13
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }
        }

        // What is live (recording, the mic, keep awake, DND), in neon.
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

        // The Crew's tube is the Crew zone: resting on it opens the Crew
        // panel, a click (on a bot or the tube) pins it.
        Tube {
            id: crewTube
            visible: (look.agents || []).length > 0
            anchors.verticalCenter: parent.verticalCenter
            hue: look.ink.cyan ?? Tokens.cyan
            fill: look.ink.ground ?? Tokens.bg
            tappable: true
            onTapped: look.pinCrew()
            CrewStrip {
                anchors.verticalCenter: parent.verticalCenter
                agents: look.agents
                dpr: look.dpr
                animated: look.animated
                tints: ({ needs: look.ink.botNeeds ?? Tokens.cyan, working: look.ink.text ?? Tokens.fg, asleep: look.ink.botAsleep ?? Tokens.inkDim })
                onClicked: look.pinCrew()
            }
        }
    }

    Row {
        id: playing
        visible: look.cell !== "rest"
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        readonly property real hugWidth: 18 + Math.ceil(playing.implicitWidth) + 18
        readonly property alias title: title
        Accessible.role: Accessible.StaticText
        Accessible.name: "Now playing: " + (look.media?.title ?? "") + (look.media?.artist ? ", " + look.media.artist : "")

        Shape {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: look.ink.play ?? Tokens.cyan
                // The board's M7 4.5 l12 7.5 -12 7.5 z in a 24 box, at 12.
                PathSvg { path: "M 3.5 2.25 L 9.5 6 L 3.5 9.75 Z" }
            }
        }
        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 320)
            text: look.media?.title ?? ""
            color: look.ink.text ?? Tokens.fg
            elide: Text.ElideRight
            font.family: "Monaspace Argon"
            font.pixelSize: 12
            textFormat: Text.PlainText
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, 200)
            text: look.media?.artist ?? ""
            color: look.ink.dim ?? Tokens.inkDim
            elide: Text.ElideRight
            font.family: "Monaspace Argon"
            font.pixelSize: 12
            textFormat: Text.PlainText
        }
    }
}
