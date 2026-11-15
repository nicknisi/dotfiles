// IslandMachine.js - the island's states and how it moves between them.
//
// A port of the Main board's prototype (main-tokens 2.4, island-modes 3.4), as
// pure functions over a small record, so tests/island-machine.cjs can drive it
// under node and Island/IslandView.qml only wires pointer events and timers to it:
//
//   { state, pinned, timer, seq, held?, item?, back?, queue? }
//
//   state   one of STATES
//   pinned  hover or crew opened by a click (or IPC), or a clicked hail, so
//           leaving (or the hail's peek timer) does not close it
//   timer   ms until the state returns to rest by itself, 0 for none
//   held    a peeking hail the pointer rested on: its timer is stopped and
//           leaving closes it, but it is not pinned, so it takes neither the
//           focus grab nor the keyboard (only a click does). A notif the
//           pointer came to: its timer paused, `left` ms to go, resumed
//           when the pointer leaves (M3 review). Absent otherwise.
//   left    a held notif's ms still to run (see `held`).
//   seq     bumps on every go(). The host restarts its timer whenever seq
//           changes, and expire() ignores a timer that started before the
//           latest go(), so a repeated go("osd") always gets a full 1400 ms.
//   item    the notification a notif state shows: { id, timeout } (M3).
//   back    the record a transient interrupted (M3): when the notif, osd,
//           dict or hail ends, finish() returns to it (timer restarted)
//           instead of rest. Rest, osd, flash and vibes are never returned
//           to: they are short, and stale once something else has shown.
//   queue   notifications waiting for the island, oldest first, as items
//           (M3). Every function carries it, go() included, and settle()
//           shows the newest once nothing that outranks a notif is up.
//
// The optional keys are left out, not set to undefined, when empty.
//
// Every function returns a new record and never changes the one it was given.
// M1 draws rest and hover, M2 the Crew's three (crew, hail, vibes), M3 the
// island's own (cal, notif, osd, dict, flash); the other states are here so
// their sizes, timers and priority have one home, and M5 to M8 fill in their
// layers.

var STATES = ["rest", "hover", "launcher", "cc", "cal", "notif", "osd", "dict", "polkit", "power", "flash", "crew", "hail", "vibes"];

// Target size per state, logical px (Main `dims`). Rest hugs its content with
// this minimum (restWidth below); flash hugs its content too, with no minimum
// (the Island board draws it narrower than the rest pill). Hover is 720 wide,
// or as wide as the rest pill when that is wider (M3: a live Context lane can
// push the pill past 720, and hover must not open from under the pointer). The Crew's
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
var HUGS = { rest: "width", hover: "width", flash: "width", hail: "width", vibes: "width", crew: "both" };
var MINS = { rest: 360, hover: 720, crew: 460 };

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
// The live segment (recording, microphone, keep awake, DND: island-modes 6)
// sits SEGMENT_GAP right of the clock, as the Island board draws it, and the
// Context lane and bots keep ZONE_GAP from it.
var SEGMENT_GAP = 12;
var ZONE_GAP = 12;

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
// hail peeks for OmniWM's PEEK = 5 s and vibes shows for its 4 s). A notif
// takes its own timeout (notifTimeout) when it has one.
var TIMERS = { notif: 4200, osd: 1400, flash: 1400, hail: 5000, vibes: 4000 };

// What an interruption is never resumed from (see `back` above).
var DROPS = ["rest", "osd", "flash", "vibes"];

// How long a notification stays (DECISION 2, island-modes 9.1): the sender's
// timeout when it sets one (expireTimeout, ms: -1 for the server's default,
// 0 for never), else the Main board's 4200; a critical one stays until
// handled (0, no timer). The toasts in the classic modes use the same rule.
function notifTimeout(expireTimeout, critical) {
    if (critical) return 0;
    var t = Number(expireTimeout);
    return t > 0 ? Math.round(t) : TIMERS.notif;
}

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

// The optional keys, copied from `from` onto the new record `r` when set.
function carry(r, from, keys) {
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i], v = from[k];
        if (v === undefined || v === null || v === false) continue;
        if (k === "queue" && !(v.length > 0)) continue;
        r[k] = v;
    }
    return r;
}

// m without its queue: what `back` holds (the queue lives on the top record).
function bare(m) {
    return carry({ state: m.state, pinned: m.pinned, timer: m.timer, seq: m.seq }, m, ["held", "left", "item", "back"]);
}

// Go to s. Pinned exactly when s is hover or crew (Main `go()`: a click or
// IPC asked for it). An unknown state changes nothing. Never held. `timer`
// (ms) replaces the state's own when given. The queue stays; what was shown
// and what it interrupted do not.
function go(m, s, timer) {
    if (!isState(s)) return m;
    var t = typeof timer === "number" && timer >= 0 ? timer : (TIMERS[s] || 0);
    return carry({ state: s, pinned: HOVERS.indexOf(s) >= 0, timer: t, seq: m.seq + 1 }, m, ["queue"]);
}

// The same state, pinned, with its timer stopped.
function pin(m) {
    return carry({ state: m.state, pinned: true, timer: 0, seq: m.seq + 1 }, m, ["item", "queue"]);
}

// A peeking hail the pointer rests on: the same card, its timer stopped,
// held (not pinned).
function hold(m) {
    return carry({ state: m.state, pinned: false, timer: 0, seq: m.seq + 1, held: true }, m, ["item", "back", "queue"]);
}

// A notif the pointer came to: its timer paused with `left` ms to go
// (the host's count; the record's own timer when it has none), held.
function pause(m, left) {
    var l = typeof left === "number" && left >= 0 ? Math.round(left) : m.timer;
    return carry({ state: m.state, pinned: false, timer: 0, seq: m.seq + 1, held: true, left: l }, m, ["item", "back", "queue"]);
}

// A paused notif's timer running again for what it had left, never less
// than RESUME_MIN, so a glance in its last moments does not drop it the
// instant the pointer goes [GUESS].
var RESUME_MIN = 1000;
function unpause(m) {
    var t = Math.max(RESUME_MIN, Number(m.left) || 0);
    return carry({ state: m.state, pinned: false, timer: t, seq: m.seq + 1 }, m, ["item", "back", "queue"]);
}

// The same record with its timer stopped and nothing else changed: `island
// hold` in the sandbox, so a self-closing state stays up for a shot.
function freeze(m) {
    return carry({ state: m.state, pinned: m.pinned, timer: 0, seq: m.seq + 1 }, m, ["held", "left", "item", "back", "queue"]);
}

// The pointer has rested on the island (after DWELL), or come to a card.
// Rest opens `target` (hover, or crew when the pointer is on the bots)
// unpinned; a peeking hail holds, so it stays while you read it and closes
// when you leave (personal-looks 3.6 says "pins"; M2 holds instead, see
// PANELS). A notif with a timer pauses with `left` ms to go and runs on
// when the pointer leaves (M3 review [GUESS]: the Main board's notif and
// today's toasts ignore the pointer); a critical one has no timer to stop.
// The host calls this for a notif only when the pointer moves onto it, so
// one that opens under a parked pointer runs its course.
function enter(m, target, left) {
    if (m.state === "rest") {
        var next = go(m, HOVERS.indexOf(target) >= 0 ? target : "hover");
        next.pinned = false;
        return next;
    }
    if (m.state === "hail" && !m.pinned && !m.held) return hold(m);
    if (m.state === "notif" && !m.held && m.timer > 0) return pause(m, left);
    return m;
}

// Whether the pointer leaving closes the state: unpinned hover or crew, and
// a held hail.
function closesOnLeave(m) {
    return !m.pinned && (HOVERS.indexOf(m.state) >= 0 || (m.state === "hail" && m.held === true));
}

// Whether the pointer leaving resumes it: a paused notif.
function resumesOnLeave(m) {
    return m.state === "notif" && m.held === true;
}

// Whether the pointer leaving changes anything (the host's grace timer).
function watchesLeave(m) {
    return closesOnLeave(m) || resumesOnLeave(m);
}

// The pointer has left the island (after LEAVE_GRACE).
function leave(m) {
    if (closesOnLeave(m)) return finish(m);
    return resumesOnLeave(m) ? unpause(m) : m;
}

// A click on the island's own background: rest opens `target` (hover, or
// crew from the bots) pinned; unpinned hover, crew or hail (peeking or held) pins.
function click(m, target) {
    if (m.state === "rest") return go(m, HOVERS.indexOf(target) >= 0 ? target : "hover");
    if ((HOVERS.indexOf(m.state) >= 0 || m.state === "hail") && !m.pinned) return pin(m);
    return m;
}

// Outside click, Esc, or IPC close: back to rest. What was interrupted stays
// closed; waiting notifications stay queued.
function dismiss(m) {
    return m.state === "rest" ? m : go(m, "rest");
}

// Back to what `b` was, from m: timer restarted, m's queue kept.
function resume(m, b) {
    return carry({ state: b.state, pinned: b.pinned, timer: b.timer, seq: m.seq + 1 }, b, ["held", "left", "item", "back"]);
}

// The newest waiting notification, shown; `back` is what it returns to.
function showNext(m, back) {
    var q = m.queue || [];
    var item = q[q.length - 1];
    var r = { state: "notif", pinned: false, timer: item.timeout, seq: m.seq + 1, item: item };
    if (q.length > 1) r.queue = q.slice(0, -1);
    if (back) r.back = back;
    return r;
}

// The state is done (its timer ran out, the pointer left a held card, its
// own Dismiss or Open, or the condition behind it ended): the next waiting
// notification when a notif ends (island-modes 9.1: one at a time, newest
// first), else back to the interrupted state, else rest.
function finish(m) {
    var r;
    if (m.state === "notif" && m.queue && m.queue.length > 0) r = showNext(m, m.back);
    else if (m.back) r = resume(m, m.back);
    else return go(m, "rest");
    return carry(r, m, r.state === "notif" && m.state === "notif" ? [] : ["queue"]);
}

// A state timer fired. seq is the record's seq when the timer was started.
function expire(m, seq) {
    if (seq !== m.seq || !(m.timer > 0)) return m;
    return finish(m);
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

// Something that opens by itself (a hail, vibes, a notif, the OSD, dictation,
// a mode flash) asks for the island: it gets it when it ranks at or above
// what is showing, else the record comes back unchanged and the caller
// queues it (notif, hail) or drops it (osd, flash, vibes). The state it
// takes over is kept as `back` (unless it is in DROPS), so finish() returns
// there; the same state offered again restarts its timer and keeps the old
// `back`. `item` is a notif's { id, timeout }.
function offer(m, s, item) {
    if (!isState(s)) return m;
    var i = PRIORITY.indexOf(s);
    if (i < 0 || i > rank(m)) return m;
    var r = go(m, s, item && typeof item.timeout === "number" ? item.timeout : undefined);
    if (item) r.item = item;
    if (m.state === s) {
        if (m.back) r.back = m.back;
    } else if (DROPS.indexOf(m.state) < 0) {
        r.back = bare(m);
    }
    return r;
}

// item waits for the island: appended to the queue, nothing else changes
// (seq too, so a running timer keeps running).
function enqueue(m, item) {
    var r = carry({ state: m.state, pinned: m.pinned, timer: m.timer, seq: m.seq }, m, ["held", "left", "item", "back"]);
    r.queue = (m.queue || []).concat([item]);
    return r;
}

// A notification arrived (DND already applied by the caller). It shows now
// when nothing outranks it; a notif already showing keeps the island and the
// new one queues behind it, as it does behind a panel, dictation or the OSD.
function notify(m, item) {
    if (m.state === "notif") return enqueue(m, item);
    var r = offer(m, "notif", item);
    return r === m ? enqueue(m, item) : r;
}

// `b` with every record showing notification `id` taken out of its chain.
function dropBack(b, id) {
    if (!b) return b;
    if (b.item && b.item.id === id) return dropBack(b.back, id);
    if (!b.back) return b;
    var r = carry({ state: b.state, pinned: b.pinned, timer: b.timer, seq: b.seq }, b, ["held", "left", "item"]);
    var rest = dropBack(b.back, id);
    if (rest) r.back = rest;
    return r;
}

// Notification `id` closed (by its sender, or dismissed from the center):
// out of the queue and the interrupted chain, and off the island if showing.
function drop(m, id) {
    var q = (m.queue || []).filter(function (x) {
        return x.id !== id;
    });
    var back = dropBack(m.back, id);
    if (q.length === (m.queue || []).length && back === m.back && !(m.item && m.item.id === id)) return m;
    var r = carry({ state: m.state, pinned: m.pinned, timer: m.timer, seq: m.seq }, m, ["held", "left", "item"]);
    if (back) r.back = back;
    if (q.length > 0) r.queue = q;
    return m.item && m.item.id === id ? finish(r) : r;
}

// Every notification id the record refers to: shown, interrupted, waiting.
function notifIds(m) {
    var ids = [];
    for (var b = m; b; b = b.back)
        if (b.item) ids.push(b.item.id);
    (m.queue || []).forEach(function (x) {
        ids.push(x.id);
    });
    return ids;
}

// What the record should be given the conditions outside it, called after
// every change: ctx = { dict, blocked }.
//   dict     dictation is running (voxtype listening or transcribing). The
//            dict state shows while it holds and ranks first among the
//            transients; when it ends, dict finishes.
//   blocked  an old surface has the island's place (a Hud hand-off): nothing
//            opens by itself, and queued notifications wait.
// Then the newest queued notification shows once nothing outranks a notif.
function settle(m, ctx) {
    var c = ctx || {};
    if (m.state === "dict" && !c.dict) return settle(finish(m), c);
    if (c.blocked) return m;
    if (c.dict && m.state !== "dict") {
        var d = offer(m, "dict");
        if (d !== m) return d;
    }
    if (m.queue && m.queue.length > 0 && m.state !== "notif") {
        var item = m.queue[m.queue.length - 1];
        var n = offer(m, "notif", item);
        if (n !== m) {
            delete n.queue;
            if (m.queue.length > 1) n.queue = m.queue.slice(0, -1);
            return n;
        }
    }
    return m;
}

// Every screen's island shows the same notifications, each on its own
// timer (M3 review). `holders` is [{ owner, ids }]: what each island's
// machine refers to. `owner` now refers to exactly `ids`. Returns the new
// list and `released`: the ids it let go of that no island holds any more,
// whose run on the islands is over (NotificationServer expires them).
function holdIds(holders, owner, ids) {
    var list = holders || [], want = ids || [], before = [], next = [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].owner === owner) before = list[i].ids;
        else next.push(list[i]);
    }
    if (want.length > 0) next.push({ owner: owner, ids: want.slice() });
    var released = before.filter(function (id) {
        return want.indexOf(id) < 0 && !next.some(function (h) {
            return h.ids.indexOf(id) >= 0;
        });
    });
    return { holders: next, released: released };
}

function radiusFor(h) {
    return Math.min(MAX_RADIUS, h / 2);
}

// Rest width from its content widths (px): at least REST_MIN, and wide enough
// that the clock can sit on the centre line with REST_CLOCK_GAP to the wider
// side zone. A live segment (segW > 0) starts SEGMENT_GAP right of the clock
// and the right zone (Context, bots) keeps ZONE_GAP from it. Rounded up to an
// even number so the centred pill lands on whole pixels (x = (screen - w) / 2).
function restWidth(clockW, leftW, rightW, segW) {
    var l = Number(leftW) || 0, r = Number(rightW) || 0, g = Number(segW) || 0;
    var right = g > 0 ? SEGMENT_GAP + g + (r > 0 ? ZONE_GAP + r : 0) : REST_CLOCK_GAP + r;
    var side = Math.max(REST_CLOCK_GAP + l, right);
    var w = Math.max(REST_MIN, (Number(clockW) || 0) + 2 * (REST_PADDING + side));
    return 2 * Math.ceil(w / 2);
}

// [w, h] for the record. A hugging state (HUGS) takes its layer's measured
// side(s) when given: widths at least MINS and rounded up to a multiple of
// WIDTH_STEP; heights capped at TALLEST, the window's room. For crew and
// hover the width given is the rest pill's (IslandView), so neither is ever
// narrower than the pill it grew from.
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
        DROPS: DROPS, DWELL: DWELL, LEAVE_GRACE: LEAVE_GRACE, MAX_RADIUS: MAX_RADIUS, WIDTH_STEP: WIDTH_STEP, REST_MIN: REST_MIN,
        REST_HEIGHT: REST_HEIGHT, REST_PADDING: REST_PADDING, REST_CLOCK_GAP: REST_CLOCK_GAP, SEGMENT_GAP: SEGMENT_GAP, ZONE_GAP: ZONE_GAP,
        TOP_INSET: TOP_INSET, TALLEST: TALLEST, SHADOW_ROOM: SHADOW_ROOM, WINDOW_HEIGHT: WINDOW_HEIGHT,
        initial: initial, isState: isState, go: go, pin: pin, hold: hold, pause: pause, unpause: unpause, RESUME_MIN: RESUME_MIN,
        freeze: freeze, enter: enter, leave: leave, closesOnLeave: closesOnLeave, resumesOnLeave: resumesOnLeave,
        watchesLeave: watchesLeave, click: click, finish: finish,
        dismiss: dismiss, expire: expire, panelOpen: panelOpen, rank: rank, offer: offer, enqueue: enqueue, notify: notify,
        drop: drop, notifIds: notifIds, settle: settle, notifTimeout: notifTimeout, holdIds: holdIds, radiusFor: radiusFor,
        restWidth: restWidth, size: size
    };
