.pragma library
// Spring.js - the island's easing curve, and an exact spring for values that
// change target while they move.
//
// The mocks ease everything on one CSS curve, linear() through the 20 STOPS
// below at even steps: the step response of a critically damped spring,
// 1 - (1 + u) e^-u, sampled at u = 0.49 i for i = 0..19, the last stop forced
// to 1. Both mock springs (spatial 1/600/49 over 400 ms, effects 1/1600/80
// over 245 ms) are critically damped, so they share that shape and differ only
// in duration. SHAPE is the u reached at the end of a run: 0.49 * 19.
//
// QML has no linear() easing. The exact port is 19 straight BezierSpline
// segments (linearSpline(), the 114 numbers in island-modes 2.2), and Qt 6.12
// cannot take it: QEasingCurve's BezierSpline keeps its segments in a
// fixed-size list, and 12 or more segments corrupt the heap the moment an
// animation evaluates the curve ("malloc(): invalid size" in qmltestrunner,
// "corrupted size vs. prev_size" in plain `qml`; 11 happened to survive, 10 is
// the most this file assumes safe). So the curve the shell uses, CURVE, is 8
// segments: the mock's own first chord, then cubic pieces through the stops at
// KNOTS with the spring's true slope at each knot. It stays within 0.0045 of
// the mock's linear() everywhere and within 0.001 of every stop.
//
// Behaviors restart from the current value with the full duration, which is
// what a CSS transition does, so fixed-target animations use CURVE. A value
// whose target moves mid-flight and must keep its speed (the Codex answer
// growing, a focus shape sliding) runs step() each frame instead. SpringAnimation
// is never used: its spring/damping units do not map to mass/stiffness/damping.

var STOPS = [0, 0.087, 0.257, 0.432, 0.583, 0.702, 0.792, 0.857, 0.902, 0.934,
             0.956, 0.971, 0.981, 0.987, 0.992, 0.995, 0.997, 0.998, 0.999, 1];
var SHAPE = 9.31;
// Qt's BezierSpline segment limit (see above): the most segments any curve here has.
var MAX_SEGMENTS = 10;
// Stop indices the shipped curve passes through.
var KNOTS = [0, 1, 2, 3, 5, 7, 10, 14, 19];

// Single-cubic fit of STOPS, max error 0.021: CSS cubic-bezier(0.30, 0.553, 0.06, 1).
var CUBIC = [0.30, 0.553, 0.06, 1.0, 1, 1];
// The `current` motion profile: today's 160 ms ease-out, cubic-bezier(0.33, 1, 0.68, 1).
var EASE_OUT = [0.33, 1, 0.68, 1, 1, 1];

function round4(v) {
    return Math.round(v * 10000) / 10000;
}

// The spring's step response, u = omega * t.
function response(u) {
    return 1 - (1 + u) * Math.exp(-u);
}

// d/dx of response(SHAPE * x): the curve's slope at progress x.
function slope(x) {
    var u = SHAPE * x;
    return SHAPE * u * Math.exp(-u);
}

// The exact port of the mock's linear(): one straight cubic per pair of stops,
// control points at 1/3 and 2/3. 6 numbers per segment, (n - 1) * 6 in all.
// Reference data only: never hand this to easing.bezierCurve (see above).
function linearSpline(stops) {
    var out = [];
    var n = stops.length - 1;
    for (var i = 0; i < n; i++) {
        var x0 = i / n, x1 = (i + 1) / n, y0 = stops[i], y1 = stops[i + 1];
        out.push(round4(x0 + (x1 - x0) / 3), round4(y0 + (y1 - y0) / 3),
                 round4(x0 + 2 * (x1 - x0) / 3), round4(y0 + 2 * (y1 - y0) / 3),
                 round4(x1), round4(y1));
    }
    return out;
}

// The shipped curve: STOPS' first chord as a straight segment, then cubic
// Hermite pieces between the KNOTS, ending flat at (1, 1).
function springSpline() {
    var n = STOPS.length - 1;
    var out = [];
    for (var k = 0; k + 1 < KNOTS.length; k++) {
        var a = KNOTS[k], b = KNOTS[k + 1];
        var x0 = a / n, x1 = b / n, y0 = STOPS[a], y1 = STOPS[b], h = x1 - x0;
        var m0, m1;
        if (k === 0) {
            m0 = m1 = (y1 - y0) / h;
        } else {
            m0 = slope(x0);
            m1 = b === n ? 0 : slope(x1);
        }
        out.push(round4(x0 + h / 3), round4(y0 + m0 * h / 3),
                 round4(x1 - h / 3), round4(y1 - m1 * h / 3),
                 round4(x1), round4(y1));
    }
    return out;
}

var CURVE = springSpline();

function segments(curve) {
    return curve.length / 6;
}

// Progress -> value for a BezierSpline list in Qt's format (start (0,0) implied,
// 3 points per segment). For tests and for anything that needs the curve's value
// without running an animation.
function valueAt(curve, x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    var px = 0, py = 0;
    for (var i = 0; i < curve.length; i += 6) {
        var ex = curve[i + 4];
        if (x <= ex || i + 6 >= curve.length) {
            var c1x = curve[i], c1y = curve[i + 1], c2x = curve[i + 2], c2y = curve[i + 3], ey = curve[i + 5];
            var lo = 0, hi = 1, t = 0.5;
            for (var n = 0; n < 60; n++) {
                t = (lo + hi) / 2;
                var s = 1 - t;
                var bx = s * s * s * px + 3 * s * s * t * c1x + 3 * s * t * t * c2x + t * t * t * ex;
                if (bx < x) lo = t; else hi = t;
            }
            var u = 1 - t;
            return u * u * u * py + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * ey;
        }
        px = ex;
        py = curve[i + 5];
    }
    return 1;
}

// Angular frequency (rad/s) of the spring that covers the curve in durationMs,
// so step() and a Behavior on the same duration move together. Zero duration
// (motion off) is an infinitely stiff spring: step() snaps.
function omegaFor(durationMs) {
    return durationMs > 0 ? SHAPE * 1000 / durationMs : Infinity;
}

// Advance a critically damped spring by dt seconds toward target, exactly:
//   x(t) = target + (d + (v + w d) t) e^(-w t),  d = x(0) - target
// so any frame time is stable and a new target keeps the current velocity.
// Returns { value, velocity } (velocity in units per second).
function step(value, velocity, target, dt, omega) {
    if (!(omega < Infinity) || !(dt >= 0))
        return { value: target, velocity: 0 };
    var d = value - target;
    var b = velocity + omega * d;
    var e = Math.exp(-omega * dt);
    return { value: target + (d + b * dt) * e, velocity: (velocity - omega * b * dt) * e };
}

// Close enough to stop driving frames: within epsilon of the target (default
// 0.01, in the value's units) and slower than epsilon per frame at 60 Hz.
function settled(value, velocity, target, epsilon) {
    var eps = epsilon > 0 ? epsilon : 0.01;
    return Math.abs(value - target) < eps && Math.abs(velocity) < eps * 60;
}
