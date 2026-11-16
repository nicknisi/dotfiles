import QtQuick
import QtQuick.Controls as Controls
import qs
import "../lib/CrewModel.js" as CrewModel

// CrewStrip.qml - the Crew on the rest pill, right zone (personal-looks 3.3).
//
// agents is Crew.agents (lib/CrewModel.js records, already sorted): one 16 px
// bot each, gap 6, bottom-aligned in an 18 px row so a hop never clips. After
// `max` bots (8, OmniWM's MAX_CREW) a "+N" in Monaspace Argon 12 `inkDim`.
// With no agents the strip is hidden and adds no width. A feed that stopped
// answering (stale) shows one sleeping bot and "?" instead, with the tooltip
// "Crew feed isn't updating".
//
// Like WorkspaceStrip, the delegates are built from the ids only and that list
// is replaced only when the ids change: the feed answers every few seconds
// with new objects for the same agents, and a rebuild would restart every
// bot's bob. Mood and the rest are bindings on the same delegates.
//
// Motion: every bot reads one Kit/CrewClock, so the strip draws at most one
// frame per tick (8 a second with a needs bot, 4 with only working ones, none
// when nobody moves). `animated` is the host's gate on top of that: the island
// clears it while the session is idle.
//
// The pointer: hovered tells the island the dwell is over the bots (the Crew
// panel opens instead of hover); a click asks to pin the Crew panel.
Item {
    id: strip

    property var agents: []
    property bool stale: false
    property real dpr: 1
    property int max: CrewModel.MAX_BOTS
    property real botSize: 16
    property real gap: 6
    property real rowHeight: 18
    property bool animated: true
    // A look's colours per mood ({ needs, working, asleep }, M9 Outrun), or
    // null for the bots' own (CrewBot's tint).
    property var tints: null

    signal clicked

    readonly property bool hovered: pointer.hovered
    // The delegates' model: shown ids, replaced only when they change.
    property var ids: []
    readonly property var byId: {
        const map = {};
        for (const a of (strip.agents || []))
            map[a.id] = a;
        return map;
    }
    readonly property int more: Math.max(0, (strip.agents || []).length - strip.max)
    readonly property int builds: bots.builds
    readonly property bool shown: strip.ids.length > 0 || strip.stale
    readonly property alias clock: stripClock
    readonly property alias tooltip: tip
    readonly property string staleText: "Crew feed isn't updating"

    // The bot drawn for ids[index], for tests.
    function botAt(index: int): Item {
        return bots.itemAt(index);
    }

    visible: shown
    implicitWidth: shown ? row.implicitWidth : 0
    implicitHeight: rowHeight
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.Grouping
    Accessible.name: strip.stale ? strip.staleText : CrewModel.summary({ total: (strip.agents || []).length, attention: (strip.agents || []).filter(a => a.attention).length })

    function sameIds(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++)
            if (a[i] !== b[i]) return false;
        return true;
    }
    function syncIds() {
        const next = strip.stale ? [] : (strip.agents || []).slice(0, strip.max).map(a => String(a.id));
        if (!sameIds(next, strip.ids)) strip.ids = next;
    }
    onAgentsChanged: syncIds()
    onStaleChanged: syncIds()
    onMaxChanged: syncIds()
    Component.onCompleted: syncIds()

    // Every second working bot starts half a bob later.
    function phaseFor(index) {
        let working = 0;
        for (let i = 0; i < index; i++) {
            const a = strip.byId[strip.ids[i]];
            if (a && a.mood === "working") working++;
        }
        return (working % 2) * 2;
    }

    CrewClock {
        id: stripClock
        step: CrewModel.clockStep(strip.ids.map(id => strip.byId[id]?.mood ?? "asleep"))
        running: strip.animated && strip.visible && Motion.loops
    }

    Row {
        id: row
        height: strip.rowHeight
        spacing: strip.gap

        Repeater {
            id: bots
            property int builds: 0
            model: strip.ids
            delegate: CrewBot {
                id: bot
                required property string modelData
                required property int index
                readonly property var agent: strip.byId[modelData] ?? null
                Binding {
                    target: bot
                    property: "tint"
                    value: strip.tints?.[bot.mood] ?? "#ffffff"
                    when: strip.tints !== null && strip.tints[bot.mood] !== undefined
                }
                y: strip.rowHeight - height
                mood: agent?.mood ?? "asleep"
                riker: agent?.riker === true
                size: strip.botSize
                dpr: strip.dpr
                phase: strip.phaseFor(index)
                clock: stripClock
                Component.onCompleted: bots.builds++
                // personal-looks 6: each bot is "{name}, {state word}".
                Accessible.ignored: false
                Accessible.role: Accessible.Graphic
                Accessible.name: (agent?.name ?? "") + ", " + (agent?.state ?? "")
            }
        }
        // The feed went quiet: one sleeping bot and a question mark.
        CrewBot {
            visible: strip.stale
            y: strip.rowHeight - height
            mood: "asleep"
            size: strip.botSize
            dpr: strip.dpr
        }
        Text {
            visible: strip.stale || strip.more > 0
            height: strip.rowHeight
            verticalAlignment: Text.AlignVCenter
            text: strip.stale ? "?" : "+" + strip.more
            color: Tokens.inkDim
            font.family: "Monaspace Argon"
            font.pixelSize: 12
            font.weight: Font.Medium
            Accessible.ignored: true
        }
    }

    HoverHandler {
        id: pointer
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.clicked()
    }

    // The stale feed's tooltip, under the pill (above it is off the screen).
    Controls.ToolTip {
        id: tip
        parent: strip
        x: Math.round((strip.width - width) / 2)
        y: strip.height + 14
        visible: strip.stale && pointer.hovered
        delay: 600
        text: strip.staleText
        padding: 8
        contentItem: Text {
            text: tip.text
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
        background: Rectangle {
            color: Tokens.overlay
            radius: 8
            border.width: 1
            border.color: Tokens.hairline
        }
    }
}
