.pragma library
// BarGeometry.js - where the classic bar sits, as pure functions (Prefs,
// Theme, BarView and the tests share them).
//
// Modes and edges (PLAN M4, the Modes board): the pill floats 8 px in from any
// edge; the full strip runs edge to edge along the top or the bottom; the rail
// is the same flush strip down the left or the right (DECISION 5: "rail
// becomes the flush full-height strip"); the island is top centre only. So a
// full strip dropped on a side edge becomes the rail, and a rail dropped on
// the top or the bottom becomes the full strip (island-modes 12.5).

var EDGES = ["top", "bottom", "left", "right"];
var THICK = 40;
var INSET = 8;
// The pill window's room for its shadow on the side away from its edge (28
// blur + 10 offset, rounded up; IslandMachine's SHADOW_ROOM). Not reserved.
var SHADOW_ROOM = 40;
var PILL_LENGTH = 518;

function side(edge) {
    return edge === "left" || edge === "right";
}

// The edge a mode draws on, given the remembered one. The island is always at
// the top; the full strip on a side edge reads as the top, the rail on the top
// or the bottom reads as the left. A mode switch never changes the remembered
// edge, so going back to the pill puts it where it was.
function edgeFor(mode, stored) {
    var e = EDGES.indexOf(stored) >= 0 ? stored : "top";
    if (mode === "island") return "top";
    if (mode === "full" && side(e)) return "top";
    if (mode === "rail" && !side(e)) return "left";
    return e;
}

// Moving the bar to `edge` in `mode`: the { mode, edge } to store, or null
// for an unknown edge. Full and rail trade places when the edge changes
// orientation; the pill and the island keep their mode.
function moveTo(mode, edge) {
    if (EDGES.indexOf(edge) < 0) return null;
    if (mode === "full" && side(edge)) return { mode: "rail", edge: edge };
    if (mode === "rail" && !side(edge)) return { mode: "full", edge: edge };
    return { mode: mode, edge: edge };
}

// capsule.json's `layout`: the version of these rules the file was written
// under. A file without it (0) is from before M4, when the rail was an 80 %
// floating capsule on any edge and the full strip ran on any edge too.
var LAYOUT = 1;

// The { mode, edge } a pre-M4 file means under these rules: read the way a
// move reads it (moveTo), so the edge it was on stays. A rail on the top
// becomes the full strip on the top (not M4's rail down the left, which
// would move the bar across the screen and reflow every window), and a full
// strip on a side becomes the rail there. Anything else is kept.
function upgrade(mode, edge) {
    return moveTo(mode, edge) || { mode: mode, edge: edge };
}

// The flush strips: full and rail run the whole edge with a hairline on the
// inner edge only, no ring, no shadow, no inset.
function flush(mode) {
    return mode === "full" || mode === "rail";
}

// Gap between the bar and its screen edge: 8 for the floating pill, 0 for the
// strips.
function inset(mode) {
    return flush(mode) ? 0 : INSET;
}

// The bar's length along its edge: the pill is 518 plus room for the media
// chip, never more than the edge minus both insets; the strips take the edge.
function length(mode, along, mediaExtra) {
    if (flush(mode)) return along;
    return Math.max(THICK, Math.min(along - 2 * INSET, PILL_LENGTH + (mediaExtra || 0)));
}

// The bar body's rectangle on its screen: { x, y, width, height }.
function body(mode, edge, screenWidth, screenHeight, length) {
    var i = inset(mode);
    var vertical = side(edge);
    var along = vertical ? screenHeight : screenWidth;
    var start = flush(mode) ? 0 : (along - length) / 2;
    if (vertical) return { x: edge === "left" ? i : screenWidth - i - THICK, y: start, width: THICK, height: length };
    return { x: start, y: edge === "top" ? i : screenHeight - i - THICK, width: length, height: THICK };
}

// Pointer coordinates are local to the edge window, not the monitor.
function nearestEdge(edge, screenWidth, screenHeight, windowWidth, windowHeight, x, y) {
    const px = Math.max(0, Math.min(screenWidth, x + (edge === "right" ? screenWidth - windowWidth : 0)));
    const py = Math.max(0, Math.min(screenHeight, y + (edge === "bottom" ? screenHeight - windowHeight : 0)));
    const distances = { top: py, bottom: screenHeight - py, left: px, right: screenWidth - px };
    let best = edge;
    for (const candidate in distances)
        if (distances[candidate] < distances[best]) best = candidate;
    return best;
}
