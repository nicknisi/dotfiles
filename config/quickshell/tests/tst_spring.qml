import QtQuick
import QtTest
import qs
import "../lib/Spring.js" as Spring

// Motion.qml and lib/Spring.js. Runs under tests/kit.sh, which loads the real
// Motion beside a stub Prefs (motion, reducedMotion).
//
// The mock's linear() port is 114 numbers (island-modes 2.2). Qt 6.12 corrupts
// its heap on any BezierSpline of 12 or more segments, so that port is checked
// here as data and never animated; the curve the shell animates with is
// checked against the same stops, and run to the end, below.
TestCase {
    id: test
    name: "Spring"
    when: windowShown
    visible: true
    width: 100
    height: 100

    // island-modes.md section 2.2, verbatim.
    readonly property var spec114: [0.0175,0.029,0.0351,0.058,0.0526,0.087, 0.0702,0.1437,0.0877,0.2003,0.1053,0.257, 0.1228,0.3153,0.1404,0.3737,0.1579,0.432, 0.1754,0.4823,0.193,0.5327,0.2105,0.583, 0.2281,0.6227,0.2456,0.6623,0.2632,0.702, 0.2807,0.732,0.2982,0.762,0.3158,0.792, 0.3333,0.8137,0.3509,0.8353,0.3684,0.857, 0.386,0.872,0.4035,0.887,0.4211,0.902, 0.4386,0.9127,0.4561,0.9233,0.4737,0.934, 0.4912,0.9413,0.5088,0.9487,0.5263,0.956, 0.5439,0.961,0.5614,0.966,0.5789,0.971, 0.5965,0.9743,0.614,0.9777,0.6316,0.981, 0.6491,0.983,0.6667,0.985,0.6842,0.987, 0.7018,0.9887,0.7193,0.9903,0.7368,0.992, 0.7544,0.993,0.7719,0.994,0.7895,0.995, 0.807,0.9957,0.8246,0.9963,0.8421,0.997, 0.8596,0.9973,0.8772,0.9977,0.8947,0.998, 0.9123,0.9983,0.9298,0.9987,0.9474,0.999, 0.9649,0.9993,0.9825,0.9997,1.0,1.0]
    // The mock's CSS linear() stops.
    readonly property var cssStops: [0, 0.087, 0.257, 0.432, 0.583, 0.702, 0.792, 0.857, 0.902, 0.934, 0.956, 0.971, 0.981, 0.987, 0.992, 0.995, 0.997, 0.998, 0.999, 1]

    property real animated: 0
    NumberAnimation {
        id: run
        target: test
        property: "animated"
        from: 0
        to: 1000
        duration: 300
        easing.type: Easing.BezierSpline
    }

    function init() {
        Prefs.motion = "spring";
        Prefs.reducedMotion = false;
    }

    // linear() between the CSS stops
    function cssAt(x) {
        if (x >= 1) return 1;
        const i = Math.floor(x * 19), t = x * 19 - i;
        return cssStops[i] + (cssStops[i + 1] - cssStops[i]) * t;
    }

    function pointsMonotonic(curve) {
        for (let i = 2; i < curve.length; i += 2)
            if (curve[i] < curve[i - 2] || curve[i + 1] < curve[i - 1]) return false;
        return true;
    }

    function test_stops_are_the_css_curve() {
        compare(Spring.STOPS, cssStops);
        // ...which is the critically damped step response at u = 0.49 i
        for (let i = 0; i < 19; i++)
            verify(Math.abs(Spring.response(0.49 * i) - cssStops[i]) <= 0.0005, "stop " + i);
    }

    function test_linear_port_is_the_114_numbers() {
        const port = Spring.linearSpline(Spring.STOPS);
        compare(port.length, 114);
        compare(spec114.length, 114);
        for (let i = 0; i < 114; i++)
            verify(Math.abs(port[i] - spec114[i]) <= 0.00005, "number " + i + ": " + port[i] + " vs " + spec114[i]);
        compare(port.slice(-2), [1, 1], "ends at (1, 1)");
        verify(pointsMonotonic(port), "x and y never step back");
        // every third pair is a stop: segment k ends at ((k + 1) / 19, stop k + 1)
        for (let k = 0; k < 19; k++) {
            verify(Math.abs(port[6 * k + 4] - (k + 1) / 19) <= 0.00005, "x of stop " + (k + 1));
            compare(port[6 * k + 5], cssStops[k + 1], "y of stop " + (k + 1));
        }
        verify(port.length / 6 > Spring.MAX_SEGMENTS, "the exact port is over Qt's limit, which is why it is not shipped");
    }

    function test_shipped_curve_is_safe_and_close() {
        const curve = Motion.springCurve;
        compare(curve, Spring.CURVE);
        compare(curve.length % 6, 0);
        verify(Spring.segments(curve) <= Spring.MAX_SEGMENTS, Spring.segments(curve) + " segments");
        compare(curve.slice(-2), [1, 1]);
        verify(pointsMonotonic(curve), "control points never step back");
        // passes through every stop and stays on the mock's linear()
        for (let i = 0; i <= 19; i++)
            verify(Math.abs(Spring.valueAt(curve, i / 19) - cssStops[i]) <= 0.001, "stop " + i + ": " + Spring.valueAt(curve, i / 19));
        let worst = 0, last = 0;
        for (let j = 0; j <= 1900; j++) {
            const x = j / 1900, y = Spring.valueAt(curve, x);
            verify(y >= last - 1e-9, "monotonic at " + x);
            last = y;
            worst = Math.max(worst, Math.abs(y - cssAt(x)));
        }
        verify(worst <= 0.005, "max deviation from linear() " + worst);
        // the first piece is the mock's own first chord
        compare(curve.slice(0, 6), Spring.linearSpline(Spring.STOPS).slice(0, 6));
    }

    function test_single_cubic_fallback() {
        let worst = 0;
        for (let i = 0; i <= 19; i++)
            worst = Math.max(worst, Math.abs(Spring.valueAt(Motion.springCubic, i / 19) - cssStops[i]));
        verify(worst <= 0.022, "cubic fit error " + worst);
    }

    // Qt evaluates the curves for real: finite, monotonic, exact at the end.
    function runCurve(curve) {
        run.easing.bezierCurve = curve;
        animated = 0;
        run.start();
        let last = 0;
        while (run.running) {
            wait(8);
            verify(isFinite(animated), "finite");
            verify(animated >= last - 1e-6, "monotonic: " + animated + " after " + last);
            last = animated;
        }
        compare(animated, 1000);
    }
    function test_qt_runs_the_spring() { runCurve(Motion.springCurve) }
    function test_qt_runs_the_cubic() { runCurve(Motion.springCubic) }
    function test_qt_runs_the_ease_out() { runCurve(Motion.easeOut) }

    function test_profiles_data() {
        return [
            {tag: "spring", motion: "spring", reduced: false, spatial: 400, effects: 245, stagger: 80, exitFade: 123, curve: "spring"},
            {tag: "current", motion: "current", reduced: false, spatial: 160, effects: 90, stagger: 0, exitFade: 45, curve: "easeOut"},
            {tag: "slow", motion: "slow", reduced: false, spatial: 1600, effects: 980, stagger: 320, exitFade: 490, curve: "spring"},
            {tag: "off", motion: "off", reduced: false, spatial: 0, effects: 0, stagger: 0, exitFade: 0, curve: "spring"},
            {tag: "unknown is spring", motion: "bouncy", reduced: false, spatial: 400, effects: 245, stagger: 80, exitFade: 123, curve: "spring"},
            {tag: "reduced spring", motion: "spring", reduced: true, spatial: 0, effects: 0, stagger: 0, exitFade: 0, curve: "spring"},
            {tag: "reduced slow", motion: "slow", reduced: true, spatial: 0, effects: 0, stagger: 0, exitFade: 0, curve: "spring"},
        ];
    }
    function test_profiles(data) {
        Prefs.motion = data.motion;
        Prefs.reducedMotion = data.reduced;
        compare(Motion.spatial, data.spatial);
        compare(Motion.effects, data.effects);
        compare(Motion.stagger, data.stagger);
        compare(Motion.exitFade, data.exitFade);
        compare(Motion.spring, data.curve === "easeOut" ? Motion.easeOut : Motion.springCurve);
        const still = data.spatial === 0;
        compare(Motion.reduced, still);
        compare(Motion.loops, !still);
        compare(Motion.spatialOmega, still ? Infinity : 9310 / data.spatial);
    }

    function test_step_is_the_exact_spring() {
        const w = Spring.omegaFor(400);
        compare(w, 9310 / 400);
        // from rest at 0 toward 1, the spring is the step response
        for (let i = 0; i <= 19; i++) {
            const t = 0.4 * i / 19;
            const s = Spring.step(0, 0, 1, t, w);
            verify(Math.abs(s.value - Spring.response(w * t)) <= 1e-12, "t " + t);
        }
        // exact, so 40 small steps land where one long step does
        let s = {value: 0, velocity: 0};
        for (let k = 0; k < 40; k++) s = Spring.step(s.value, s.velocity, 1, 0.01, w);
        const once = Spring.step(0, 0, 1, 0.4, w);
        verify(Math.abs(s.value - once.value) <= 1e-12 && Math.abs(s.velocity - once.velocity) <= 1e-9);
        // and its velocity is the derivative of its position
        const a = Spring.step(0, 0, 1, 0.1, w), b = Spring.step(0, 0, 1, 0.1 + 1e-6, w);
        verify(Math.abs((b.value - a.value) / 1e-6 - a.velocity) <= 1e-4);
    }

    function test_step_retargets_with_its_speed() {
        const w = Spring.omegaFor(400);
        const mid = Spring.step(0, 0, 100, 0.1, w);
        verify(mid.velocity > 0);
        // a new target keeps the current position and velocity
        const next = Spring.step(mid.value, mid.velocity, 300, 0, w);
        compare(next.value, mid.value);
        compare(next.velocity, mid.velocity);
        let s = mid;
        for (let k = 0; k < 120; k++) s = Spring.step(s.value, s.velocity, 300, 1 / 60, w);
        verify(Spring.settled(s.value, s.velocity, 300), "settles: " + s.value);
        verify(!Spring.settled(mid.value, mid.velocity, 300));
        // critically damped: never passes the target
        let p = {value: 0, velocity: 0}, peak = 0;
        for (let k = 0; k < 120; k++) { p = Spring.step(p.value, p.velocity, 1, 1 / 60, w); peak = Math.max(peak, p.value) }
        verify(peak <= 1, "no overshoot");
    }

    function test_step_snaps_when_motion_is_off() {
        compare(Spring.omegaFor(0), Infinity);
        const s = Spring.step(3, 50, 10, 0.016, Spring.omegaFor(0));
        compare(s.value, 10);
        compare(s.velocity, 0);
    }
}
