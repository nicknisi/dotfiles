import QtQuick
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine

// RestLayer.qml - the rest pill's content (island-modes 5, Main and Island boards).
//
//   ←16→[ W C (D) S ]          10:45          [ dotfiles  bot bot bot ]←16→
//
// Left: the workspace letters. Centre: the clock, on the screen's centre line.
// Right: the Context lane (island-modes 5.4: an icon 14 in the kind's colour,
// the text 12 `fg` elided at 180, the extra in Monaspace 11 `inkDim`; the
// sparkle breathes in `accent` while an agent works), then the Crew's bots
// (Kit/CrewStrip, 10 after the lane, hidden with no agents).
// While something is live (a recording, the microphone, keep awake, DND), the
// live segment (Island/LiveSegment) sits 12 right of the clock and the pill
// grows around it (M3; it replaces M2's privacy dot).
// The pill hugs its content with a 360 minimum (420 in the notch, minWidth):
// hugWidth is the rest width rule in lib/IslandMachine.js, which widens both
// sides together so the clock never leaves the centre.
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
    // Context.lane: { kind, icon, text, extra, working }.
    property var lane: ({})
    // { recording, elapsed, mic: [names], awake, awakeLeft, dnd }
    property var live: ({})
    // Crew.agents and Crew.stale, and the window's devicePixelRatio for the bots.
    property var crew: []
    property bool crewStale: false
    property real dpr: 1
    // The bots' loops, and the working sparkle's, run only while this holds
    // (the session not idle). The recording dot ignores it: it is a privacy
    // signal, and a recording with no input for a minute (presenting,
    // watching) must still show it breathing.
    property bool crewAnimated: true
    // The recording dot breathes only while this holds: a fixture's `still`
    // (a sandbox shot), never idle.
    property bool dotAnimated: true
    // The gap between the letters' cells: 2, or 0 in the notch form, whose
    // cells touch (island-modes 5.2 and 8.2, the Island board's notch).
    property real cellGap: 2
    // The pill's floor: 360, or the notch's 420 (IslandMachine.NOTCH_REST_MIN).
    property real minWidth: IslandMachine.REST_MIN

    signal workspaceActivated(string name)
    signal pin
    signal pinCrew
    signal stopRecording

    readonly property real hugWidth: IslandMachine.restWidth(clockText.implicitWidth, strip.implicitWidth, right.implicitWidth, segment.implicitWidth)
    readonly property alias strip: strip
    readonly property alias crewStrip: crewStrip
    readonly property alias segment: segment
    readonly property alias clockText: clockText
    readonly property alias laneRow: laneRow
    readonly property alias laneIcon: laneIcon
    readonly property alias contextText: contextText
    readonly property alias laneExtra: laneExtra
    readonly property bool crewHovered: crewStrip.visible && crewStrip.hovered

    // The breathing marks (M3 review): the working sparkle (1.6 s) and the
    // recording dot (1.4 s) take their opacity from Motion.breath on a
    // stepped clock, never a smooth loop. While the bots move they read the
    // strip's own clock, so the pill draws nothing the bots do not already
    // draw; otherwise breathClock steps at 250 ms (4 frames a second).
    readonly property bool sparkleBreathes: rest.lane?.working === true && rest.current && rest.crewAnimated && Motion.loops
    readonly property bool dotBreathes: segment.recording && rest.current && rest.dotAnimated && Motion.loops
    readonly property real breathElapsed: crewStrip.clock.ticking ? crewStrip.clock.elapsed : breathClock.elapsed
    readonly property alias breathClock: breathClock
    CrewClock {
        id: breathClock
        step: 250
        running: (rest.sparkleBreathes || rest.dotBreathes) && !crewStrip.clock.ticking
    }

    // As wide as the island it sits in (hugWidth rounded the way the body
    // rounds it), so the centred layer starts on the body's own pixel: a 390
    // layer in a 392 body would sit 1 px in, half a device pixel at 1.5.
    width: IslandMachine.size({ state: "rest" }, hugWidth, 0, minWidth)[0]
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
        gap: rest.cellGap
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

    // Right of the clock, above the opener so Stop takes its own click.
    LiveSegment {
        id: segment
        x: Math.round(clockText.x + clockText.implicitWidth + IslandMachine.SEGMENT_GAP)
        anchors.verticalCenter: parent.verticalCenter
        recording: rest.live?.recording === true
        elapsed: rest.live?.elapsed ?? ""
        mic: rest.live?.mic ?? []
        awake: rest.live?.awake === true
        awakeLeft: rest.live?.awakeLeft ?? ""
        dnd: rest.live?.dnd === true
        dotOpacity: rest.dotBreathes ? Motion.breath(rest.breathElapsed, 1400, 0.45) : 1
        onStop: rest.stopRecording()
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: IslandMachine.REST_PADDING
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // The Context lane. Hidden, so no width, while nothing is focused.
        Row {
            id: laneRow
            anchors.verticalCenter: parent.verticalCenter
            visible: contextText.text !== ""
            spacing: 6
            Accessible.role: Accessible.StaticText
            Accessible.name: [rest.lane?.text ?? "", rest.lane?.extra ?? ""].filter(s => s !== "").join(" ")

            Icon {
                id: laneIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: name !== ""
                name: rest.lane?.icon ?? ""
                size: 14
                // "The accent appears only when an agent is working."
                color: rest.lane?.working === true ? Tokens.accent : Tokens.inkDim
                opacity: rest.sparkleBreathes ? Motion.breath(rest.breathElapsed, 1600, 0.45) : 1
            }
            Text {
                id: contextText
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 180)
                text: rest.lane?.text ?? ""
                color: Tokens.fg
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Text {
                id: laneExtra
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: rest.lane?.extra ?? ""
                color: Tokens.inkDim
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.pixelSize: 11
            }
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
