import QtQuick
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine

// RestLayer.qml - the rest pill's content (island-modes 5, Main and Island boards).
//
//   ←16→[ W C (D) S ]          10:45          [ dotfiles  bot bot bot ]←16→
//
// Left: the workspace letters. Centre: the clock, on the screen's centre line.
// Right: the Context text (fixtures only until M3, see IslandView), then the
// Crew's bots (Kit/CrewStrip, 10 after the text, hidden with no agents).
// While the screen is recorded or an app holds the microphone, a `bad` dot
// leads the right zone: the Bar's privacy glyphs, kept as a stopgap until
// M3's live segment replaces it.
// The pill hugs its content with a 360 minimum: hugWidth is the rest width rule
// in lib/IslandMachine.js, which widens both sides together so the clock never
// leaves the centre.
//
// One button covers the whole layer ("Open the island", Main): a click on empty
// pill space pins hover at once. The letters sit above it and take their own
// clicks, which is why hover waits for a dwell instead of opening on enter.
// The bots are a second zone (DECISION 1): resting on them opens the Crew
// panel instead of hover (crewHovered tells the view), and a click there pins
// the Crew panel (pinCrew).
//
// Data comes in as plain values (Island/IslandView reads the services and
// fixtures), so the layer never touches Hyprland or Context itself.
Layer {
    id: rest

    property var workspaces: []
    property string clock: ""
    property string context: ""
    property bool privacy: false
    // Crew.agents and Crew.stale, and the window's devicePixelRatio for the bots.
    property var crew: []
    property bool crewStale: false
    property real dpr: 1
    // The bots' loops run only while this holds (the session not idle).
    property bool crewAnimated: true

    signal workspaceActivated(string name)
    signal pin
    signal pinCrew

    readonly property real hugWidth: IslandMachine.restWidth(clockText.implicitWidth, strip.implicitWidth, right.implicitWidth)
    readonly property alias strip: strip
    readonly property alias crewStrip: crewStrip
    readonly property alias privacyDot: privacyDot
    readonly property alias contextText: contextText
    readonly property bool crewHovered: crewStrip.visible && crewStrip.hovered

    // As wide as the island it sits in (hugWidth rounded the way the body
    // rounds it), so the centred layer starts on the body's own pixel: a 390
    // layer in a 392 body would sit 1 px in, half a device pixel at 1.5.
    width: IslandMachine.size({ state: "rest" }, hugWidth)[0]
    height: IslandMachine.REST_HEIGHT

    MouseArea {
        id: opener
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: rest.pin()
        Accessible.role: Accessible.Button
        Accessible.name: "Open the island"
        Accessible.onPressAction: rest.pin()
    }

    WorkspaceStrip {
        id: strip
        x: IslandMachine.REST_PADDING
        anchors.verticalCenter: parent.verticalCenter
        items: rest.workspaces
        onActivated: name => rest.workspaceActivated(name)
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: rest.clock
        color: Tokens.fg
        font.family: "Monaspace Argon"
        font.pixelSize: 13
        font.weight: Font.Medium
        Accessible.role: Accessible.StaticText
        Accessible.name: rest.clock
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: IslandMachine.REST_PADDING
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            id: privacyDot
            anchors.verticalCenter: parent.verticalCenter
            visible: rest.privacy
            width: 8
            height: 8
            radius: 4
            color: Tokens.bad
            Accessible.role: Accessible.Indicator
            Accessible.name: "Recording or microphone in use"
        }
        Text {
            id: contextText
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            width: Math.min(implicitWidth, 180)
            text: rest.context
            color: Tokens.fg
            elide: Text.ElideRight
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            Accessible.role: Accessible.StaticText
            Accessible.name: rest.context
        }
        // The Crew. Hidden, so no width and no spacing, while nobody is aboard.
        CrewStrip {
            id: crewStrip
            anchors.verticalCenter: parent.verticalCenter
            agents: rest.crew
            stale: rest.crewStale
            dpr: rest.dpr
            animated: rest.crewAnimated && rest.current
            onClicked: rest.pinCrew()
        }
    }
}
