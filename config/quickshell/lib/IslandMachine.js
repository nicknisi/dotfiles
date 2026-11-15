// IslandMachine.js - the island's states and how it moves between them.
//
// A port of the Main board's prototype (main-tokens 2.4, island-modes 3.4), as
// pure functions over a small record, so tests/island-machine.cjs can drive it
// under node and Island/IslandView.qml only wires pointer events and timers to it:
//
//   { state, pinned, timer, seq }
//
//   state   one of STATES
//   pinned  hover opened by a click (or IPC), so leaving does not close it
//   timer   ms until the state returns to rest by itself, 0 for none
//   seq     bumps on every go(). The host restarts its timer whenever seq
//           changes, and expire() ignores a timer that started before the
//           latest go(), so a repeated go("osd") always gets a full 1400 ms.
//
// Every function returns a new record and never changes the one it was given.
// M1 draws rest and hover; the other states are here so their sizes, timers
// and priority have one home, and M3 to M8 fill in their layers.

var STATES = ["rest", "hover", "launcher", "cc", "cal", "notif", "osd", "dict", "polkit", "power", "flash"];

// Target size per state, logical px (Main `dims`). Rest hugs its content with
// this minimum (restWidth below); flash hugs its content too (M3).
var DIMS = {
    rest: [360, 38],
    hover: [720, 136],
    launcher: [760, 472],
    cc: [760, 560],
    cal: [400, 368],
    notif: [520, 92],
    osd: [340, 44],
    dict: [360, 48],
    polkit: [480, 272],
    power: [600, 156],
    flash: [360, 52]
};

// The tallest state, cc, sets the island window's height: 8 inset + 560 + 40
// for the shadow (28 blur + 10 offset, rounded up).
var TOP_INSET = 8;
var TALLEST = 560;
var SHADOW_ROOM = 40;
var WINDOW_HEIGHT = TOP_INSET + TALLEST + SHADOW_ROOM;

var MAX_RADIUS = 28;
var REST_MIN = 360;
var REST_HEIGHT = 38;
// Rest layout: 16 padding at each end, and at least 24 between the clock and
// either side zone, so the clock stays on the screen's centre line.
var REST_PADDING = 16;
var REST_CLOCK_GAP = 24;

// States that own the island until the user dismisses them: outside clicks
// close them (HyprlandFocusGrab), so they count as an open panel. Hover joins
// them while pinned.
var PANELS = ["launcher", "cc", "cal", "polkit", "power"];

// Who wins when two things want the island at once, highest first
// (island-modes 3.4 [GUESS]). "panel" is any open panel the user chose,
// pinned hover included; "live" is the rest pill grown by an indicator. M3
// arbitrates with it; M1 only states it.
var PRIORITY = ["polkit", "panel", "dict", "osd", "notif", "flash", "live", "rest"];

// Self-closing states, ms (Main: notif 4200, osd 1400; flash per 6.3 [GUESS]).
var TIMERS = { notif: 4200, osd: 1400, flash: 1400 };

// Pointer timing (island-modes 5.7, DECISION 1): hover opens after the pointer
// rests DWELL ms on the pill, so a click on a workspace letter lands first;
// leaving waits LEAVE_GRACE ms so crossing the morphing edge does not bounce.
var DWELL = 250;
var LEAVE_GRACE = 150;

function initial() {
    return { state: "rest", pinned: false, timer: 0, seq: 0 };
}

function isState(s) {
    return STATES.indexOf(s) >= 0;
}

// Go to s. Pinned exactly when s is hover (Main `go()`). An unknown state
// changes nothing.
function go(m, s) {
    if (!isState(s)) return m;
    return { state: s, pinned: s === "hover", timer: TIMERS[s] || 0, seq: m.seq + 1 };
}

// The pointer has rested on the island (after DWELL). Only rest opens.
function enter(m) {
    if (m.state !== "rest") return m;
    var next = go(m, "hover");
    next.pinned = false;
    return next;
}

// The pointer has left the island (after LEAVE_GRACE). Only unpinned hover closes.
function leave(m) {
    return m.state === "hover" && !m.pinned ? go(m, "rest") : m;
}

// A click on the island's own background: rest opens pinned, unpinned hover pins.
function click(m) {
    if (m.state === "rest" || (m.state === "hover" && !m.pinned)) return go(m, "hover");
    return m;
}

// Outside click, Esc, or a state timer: back to rest.
function dismiss(m) {
    return m.state === "rest" ? m : go(m, "rest");
}

// A state timer fired. seq is the record's seq when the timer was started.
function expire(m, seq) {
    if (seq !== m.seq || !(m.timer > 0)) return m;
    return go(m, "rest");
}

// Outside clicks close the island (the focus grab is active) only while this holds.
function panelOpen(m) {
    return PANELS.indexOf(m.state) >= 0 || (m.state === "hover" && m.pinned);
}

// Position in PRIORITY, 0 highest. An open panel of any kind ranks as "panel";
// unpinned hover ranks with rest, since a transient may take over from it.
function rank(m) {
    var key = m.state === "polkit" ? "polkit" : panelOpen(m) ? "panel" : m.state === "hover" ? "rest" : m.state;
    var i = PRIORITY.indexOf(key);
    return i < 0 ? PRIORITY.length - 1 : i;
}

function radiusFor(h) {
    return Math.min(MAX_RADIUS, h / 2);
}

// Rest width from its content widths (px): at least REST_MIN, and wide enough
// that the clock can sit on the centre line with REST_CLOCK_GAP to the wider
// side zone. Rounded up to an even number so the centred pill lands on whole
// pixels (x = (screen - w) / 2).
function restWidth(clockW, leftW, rightW) {
    var side = Math.max(Number(leftW) || 0, Number(rightW) || 0);
    var w = Math.max(REST_MIN, (Number(clockW) || 0) + 2 * (REST_PADDING + REST_CLOCK_GAP + side));
    return 2 * Math.ceil(w / 2);
}

// [w, h] for the record; rest (and flash) use the hugged width when given.
function size(m, hugWidth) {
    var d = DIMS[m.state] || DIMS.rest;
    if ((m.state === "rest" || m.state === "flash") && hugWidth > 0)
        return [Math.max(d[0], hugWidth), d[1]];
    return [d[0], d[1]];
}

if (typeof module !== "undefined")
    module.exports = {
        STATES: STATES, DIMS: DIMS, PANELS: PANELS, PRIORITY: PRIORITY, TIMERS: TIMERS,
        DWELL: DWELL, LEAVE_GRACE: LEAVE_GRACE, MAX_RADIUS: MAX_RADIUS, REST_MIN: REST_MIN,
        REST_HEIGHT: REST_HEIGHT, REST_PADDING: REST_PADDING, REST_CLOCK_GAP: REST_CLOCK_GAP,
        TOP_INSET: TOP_INSET, TALLEST: TALLEST, SHADOW_ROOM: SHADOW_ROOM, WINDOW_HEIGHT: WINDOW_HEIGHT,
        initial: initial, isState: isState, go: go, enter: enter, leave: leave, click: click,
        dismiss: dismiss, expire: expire, panelOpen: panelOpen, rank: rank, radiusFor: radiusFor,
        restWidth: restWidth, size: size
    };
