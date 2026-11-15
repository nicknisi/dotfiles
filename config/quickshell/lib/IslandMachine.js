// IslandMachine.js - the island's states and how it moves between them.
//
// A port of the Main board's prototype (main-tokens 2.4, island-modes 3.4), as
// pure functions over a small record, so tests/island-machine.cjs can drive it
// under node and Island/IslandView.qml only wires pointer events and timers to it:
//
//   { state, pinned, timer, seq, held? }
//
//   state   one of STATES
//   pinned  hover or crew opened by a click (or IPC), or a clicked hail, so
//           leaving (or the hail's peek timer) does not close it
//   timer   ms until the state returns to rest by itself, 0 for none
//   held    a peeking hail the pointer rested on: its timer is stopped and
//           leaving closes it, but it is not pinned, so it takes neither the
//           focus grab nor the keyboard (only a click does). Absent otherwise.
//   seq     bumps on every go(). The host restarts its timer whenever seq
//           changes, and expire() ignores a timer that started before the
//           latest go(), so a repeated go("osd") always gets a full 1400 ms.
//
// Every function returns a new record and never changes the one it was given.
// M1 draws rest and hover, M2 the Crew's three (crew, hail, vibes); the other
// states are here so their sizes, timers and priority have one home, and M3
// to M8 fill in their layers.

var STATES = ["rest", "hover", "launcher", "cc", "cal", "notif", "osd", "dict", "polkit", "power", "flash", "crew", "hail", "vibes"];

// Target size per state, logical px (Main `dims`). Rest hugs its content with
// this minimum (restWidth below); flash hugs its content too (M3). The Crew's
// states hug as well (HUGS): the panel is as tall as its rows and 460 wide, or
// as wide as the rest pill when that is wider (so the bots that opened it stay
// under it, DECISION 1); the hail card is 52 and vibes 44 high, each as wide
// as its line. Their entries here are what they take before their layer has
// measured itself.
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
    flash: [360, 52],
    crew: [460, 332],
    hail: [360, 52],
    vibes: [240, 44]
};

// Which side of each hugging state follows its content, and its minimum.
var HUGS = { rest: "width", flash: "width", hail: "width", vibes: "width", crew: "both" };
var MINS = { rest: 360, flash: 360, crew: 460 };

// The tallest state, cc, sets the island window's height: 8 inset + 560 + 40
// for the shadow (28 blur + 10 offset, rounded up).
var TOP_INSET = 8;
var TALLEST = 560;
var SHADOW_ROOM = 40;
var WINDOW_HEIGHT = TOP_INSET + TALLEST + SHADOW_ROOM;

var MAX_RADIUS = 28;
// Hugged widths round up to this (see size()).
var WIDTH_STEP = 4;
var REST_MIN = 360;
var REST_HEIGHT = 38;
// Rest layout: 16 padding at each end, and at least 24 between the clock and
// either side zone, so the clock stays on the screen's centre line.
var REST_PADDING = 16;
var REST_CLOCK_GAP = 24;

// States that own the island until the user dismisses them: outside clicks
// close them (HyprlandFocusGrab), so they count as an open panel. Hover, the
// crew panel and a hail join them while pinned (a click or IPC), never from
// the pointer alone: a hail can open under a pointer that was not reaching
// for it, and the panel's focus grab would take the keyboard from the window
// being typed in (M2 review).
var PANELS = ["launcher", "cc", "cal", "polkit", "power"];
// Opened by the pointer resting on the island, closed by it leaving, unless pinned.
var HOVERS = ["hover", "crew"];

// Who wins when two things want the island at once, highest first
// (island-modes 3.4 [GUESS]). "panel" is any open panel the user chose,
// pinned hover, crew and hail included; "live" is the rest pill grown by an
// indicator. A hail waits behind an open panel (personal-looks 3.6) and vibes,
// an easter egg, behind anything that is not rest. M3 arbitrates the rest of
// the list; M2 uses it through offer().
var PRIORITY = ["polkit", "panel", "dict", "osd", "notif", "hail", "flash", "vibes", "live", "rest"];

// Self-closing states, ms (Main: notif 4200, osd 1400; flash per 6.3 [GUESS];
// hail peeks for OmniWM's PEEK = 5 s and vibes shows for its 4 s).
var TIMERS = { notif: 4200, osd: 1400, flash: 1400, hail: 5000, vibes: 4000 };

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

// Go to s. Pinned exactly when s is hover or crew (Main `go()`: a click or
// IPC asked for it). An unknown state changes nothing. Never held.
function go(m, s) {
    if (!isState(s)) return m;
    return { state: s, pinned: HOVERS.indexOf(s) >= 0, timer: TIMERS[s] || 0, seq: m.seq + 1 };
}

// The same state, pinned, with its timer stopped.
function pin(m) {
    return { state: m.state, pinned: true, timer: 0, seq: m.seq + 1 };
}

// A peeking hail the pointer rests on: the same hail, its timer stopped,
// held (not pinned).
function hold(m) {
    return { state: m.state, pinned: false, timer: 0, seq: m.seq + 1, held: true };
}

// The pointer has rested on the island (after DWELL). Rest opens `target`
// (hover, or crew when the pointer is on the bots) unpinned; a peeking hail
// holds, so it stays while you read it and closes when you leave (personal-
// looks 3.6 says "pins"; M2 holds instead, see PANELS).
function enter(m, target) {
    if (m.state === "rest") {
        var next = go(m, HOVERS.indexOf(target) >= 0 ? target : "hover");
        next.pinned = false;
        return next;
    }
    if (m.state === "hail" && !m.pinned && !m.held) return hold(m);
    return m;
}

// Whether the pointer leaving closes the state: unpinned hover or crew, and a held hail.
function closesOnLeave(m) {
    return !m.pinned && (HOVERS.indexOf(m.state) >= 0 || (m.state === "hail" && m.held === true));
}

// The pointer has left the island (after LEAVE_GRACE).
function leave(m) {
    return closesOnLeave(m) ? go(m, "rest") : m;
}

// A click on the island's own background: rest opens `target` (hover, or
// crew from the bots) pinned; unpinned hover, crew or hail (peeking or held) pins.
function click(m, target) {
    if (m.state === "rest") return go(m, HOVERS.indexOf(target) >= 0 ? target : "hover");
    if ((HOVERS.indexOf(m.state) >= 0 || m.state === "hail") && !m.pinned) return pin(m);
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
    return PANELS.indexOf(m.state) >= 0 || ((HOVERS.indexOf(m.state) >= 0 || m.state === "hail") && m.pinned);
}

// Position in PRIORITY, 0 highest. An open panel of any kind ranks as "panel";
// unpinned hover or crew ranks with rest, since a transient may take over from it.
function rank(m) {
    var key = m.state === "polkit" ? "polkit" : panelOpen(m) ? "panel" : HOVERS.indexOf(m.state) >= 0 ? "rest" : m.state;
    var i = PRIORITY.indexOf(key);
    return i < 0 ? PRIORITY.length - 1 : i;
}

// Something that opens by itself (a hail, vibes) asks for the island: it gets
// it when it ranks at or above what is showing, else the record comes back
// unchanged and the caller may queue it.
function offer(m, s) {
    if (!isState(s)) return m;
    var i = PRIORITY.indexOf(s);
    return i >= 0 && i <= rank(m) ? go(m, s) : m;
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

// [w, h] for the record. A hugging state (HUGS) takes its layer's measured
// side(s) when given: widths at least MINS and rounded up to a multiple of
// WIDTH_STEP; heights capped at TALLEST, the window's room. For crew the
// width given is the rest pill's (IslandView), so the panel is never narrower
// than the pill it grew from.
//
// WIDTH_STEP is 4, not 2, for scale 1.5: the island is centred, so its x is
// half the screen minus half its width, and only an even x is a whole device
// pixel (x 765 is 1147.5 px). The body clips through a texture, and one drawn
// half a device pixel off blurs every vertical edge inside it, the bots' cells
// included (M2, seen on the physical shot). Every DIMS width is already a
// multiple of 4.
function size(m, hugWidth, hugHeight) {
    var d = DIMS[m.state] || DIMS.rest;
    var side = HUGS[m.state];
    var w = d[0], h = d[1];
    if ((side === "width" || side === "both") && hugWidth > 0)
        w = Math.max(MINS[m.state] || 0, WIDTH_STEP * Math.ceil(hugWidth / WIDTH_STEP));
    if ((side === "height" || side === "both") && hugHeight > 0)
        h = Math.min(TALLEST, Math.ceil(hugHeight));
    return [w, h];
}

if (typeof module !== "undefined")
    module.exports = {
        STATES: STATES, DIMS: DIMS, HUGS: HUGS, MINS: MINS, PANELS: PANELS, HOVERS: HOVERS, PRIORITY: PRIORITY, TIMERS: TIMERS,
        DWELL: DWELL, LEAVE_GRACE: LEAVE_GRACE, MAX_RADIUS: MAX_RADIUS, WIDTH_STEP: WIDTH_STEP, REST_MIN: REST_MIN,
        REST_HEIGHT: REST_HEIGHT, REST_PADDING: REST_PADDING, REST_CLOCK_GAP: REST_CLOCK_GAP,
        TOP_INSET: TOP_INSET, TALLEST: TALLEST, SHADOW_ROOM: SHADOW_ROOM, WINDOW_HEIGHT: WINDOW_HEIGHT,
        initial: initial, isState: isState, go: go, pin: pin, hold: hold, enter: enter, leave: leave,
        closesOnLeave: closesOnLeave, click: click,
        dismiss: dismiss, expire: expire, panelOpen: panelOpen, rank: rank, offer: offer, radiusFor: radiusFor,
        restWidth: restWidth, size: size
    };
