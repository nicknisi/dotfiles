import QtQuick
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine
import "../lib/WorkspaceOrder.js" as WorkspaceOrder

// LookLayer.qml - a personal look's cell on the island (PLAN M9,
// personal-looks 4).
//
// Hosts Looks/<Name>.qml for the look on screen (Look.current) in one of its
// two cells: "rest", its rest bar in place of Island/RestLayer, or "moment",
// its moment line (the `moment` state, or the `hail` state for Bridge and
// Arcade, whose moment line is their hail). The view sets `cell`, the state
// it sizes against (`sizeState`) and the data; the look draws on the body's
// material (Look.material, set on Island/IslandBody by the view), so it adds
// no background of its own.
//
// A look restyles the rest pill, not what it does (personal-looks 4.0), so
// the rest bar keeps the pill's pointer and its live segment:
//   - a click on empty bar pins hover (pin), as on the plain pill;
//   - each look's letters take their own clicks (activated(name)), and the
//     wheel over them steps the workspaces with Kit/WorkspaceStrip's rule
//     (lib/WorkspaceOrder.js wheel(): 120 a notch, no wrap);
//   - each look names its Crew zone (Phosphor's faces, Bridge's away team,
//     Arcade's invaders, Liner Notes' stamp, Outrun's crew tube):
//     crewHovered tells the view's dwell to open the Crew panel instead of
//     hover (DECISION 1), and a click there pins it (pinCrew);
//   - `live` is the view's live record (recording, elapsed, mic, awake,
//     awakeLeft, dnd): each look draws Island/LiveSegment in its inks, its
//     recording dot breathing on this layer's stepped clock (a privacy
//     signal: idle never holds it, as on the plain pill), and its Stop comes
//     out as stopRecording.
//
// Built only while a look is on, so the plain island loads none of this.
Layer {
    id: layer

    property string cell: "rest"
    property string sizeState: "rest"
    property real cellHeight: IslandMachine.REST_HEIGHT
    // The width floor: 0 for a look's rest bar (the board packs it), -1 for
    // the state's own (IslandMachine.size).
    property real minWidth: -1

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
    // { recording, elapsed, mic, awake, awakeLeft, dnd } (IslandView.live).
    property var live: ({})
    // The recording dot breathes only while this holds: a fixture's `still`.
    property bool dotAnimated: true

    signal pin
    signal go
    signal pinCrew
    signal activated(string name)
    signal stopRecording

    readonly property var content: loader.item
    readonly property real hugWidth: loader.item ? loader.item.hugWidth : 0
    readonly property string look: Look.active ? Look.current : ""
    // The pointer rests on the look's Crew zone (only while this cell is up).
    readonly property bool crewHovered: layer.current && loader.item !== null && loader.item.crewHovered === true

    // The wheel's running sum (WorkspaceOrder.wheel).
    property real wheelAccumulator: 0
    function step(delta: real) {
        const list = layer.workspaces || [];
        const names = list.map(w => String(w?.name ?? ""));
        const focused = list.find(w => w && w.focused === true);
        const r = WorkspaceOrder.wheel(layer.wheelAccumulator, delta, names, focused ? String(focused.name) : "");
        layer.wheelAccumulator = r.acc;
        if (r.name !== "") layer.activated(r.name);
    }

    // The recording dot's breath (RestLayer's: Motion.breath over 1.4 s on a
    // 250 ms step, so the dot costs four frames a second while it records).
    readonly property bool dotBreathes: layer.cell === "rest" && layer.current && layer.live?.recording === true && layer.dotAnimated && Motion.loops
    readonly property alias breathClock: breathClock
    CrewClock {
        id: breathClock
        step: 250
        running: layer.dotBreathes
    }
    readonly property real dotOpacity: layer.dotBreathes ? Motion.breath(breathClock.elapsed, 1400, 0.45) : 1

    // The island's width, rounded as the body rounds it (see HailCard).
    width: IslandMachine.size({ state: layer.sizeState }, layer.hugWidth, 0, layer.minWidth >= 0 ? layer.minWidth : undefined)[0]
    height: layer.cellHeight

    // A click on the bar pins hover, as on the plain rest pill; a hail
    // look's moment line pins the hail (its button jumps).
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: layer.pin()
        Accessible.role: Accessible.Button
        Accessible.name: layer.cell === "rest" ? "Open the island" : "Pin"
        Accessible.onPressAction: layer.pin()
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: layer.look !== ""
        source: layer.look === "" ? "" : Qt.resolvedUrl("../Looks/" + layer.look.charAt(0).toUpperCase() + layer.look.slice(1) + ".qml")
        onLoaded: {
            item.cell = Qt.binding(() => layer.cell);
            item.ink = Qt.binding(() => Look.ink);
            item.workspaces = Qt.binding(() => layer.workspaces);
            item.clock = Qt.binding(() => layer.clock);
            item.now = Qt.binding(() => layer.now);
            item.agents = Qt.binding(() => layer.agents);
            item.total = Qt.binding(() => layer.total);
            item.spend = Qt.binding(() => layer.spend);
            item.battery = Qt.binding(() => layer.battery);
            item.media = Qt.binding(() => layer.media);
            item.tagline = Qt.binding(() => layer.tagline);
            item.hailAgent = Qt.binding(() => layer.hailAgent);
            item.hailOthers = Qt.binding(() => layer.hailOthers);
            item.dpr = Qt.binding(() => layer.dpr);
            item.animated = Qt.binding(() => layer.animated && layer.current);
            item.live = Qt.binding(() => layer.cell === "rest" ? layer.live : ({}));
            item.dotOpacity = Qt.binding(() => layer.dotOpacity);
            item.go.connect(layer.go);
            item.activated.connect(layer.activated);
            item.pinCrew.connect(layer.pinCrew);
            item.wheeled.connect(layer.step);
            item.stopRecording.connect(layer.stopRecording);
        }
    }
}
