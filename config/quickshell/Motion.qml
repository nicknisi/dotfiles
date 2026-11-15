pragma Singleton
// Motion.qml - how long island animations take, and the curve they ease on.
// (pragma Singleton stays above every brace, comments included: see Icons.qml.)
//
// Size, position, radius and transforms move over `spatial`; opacity and
// colour change over `effects`. An incoming content layer waits `stagger`
// before it fades in, and an outgoing one fades out over `exitFade`, linear
// (Kit/Layer.qml is the one place that choreography lives). Everything else
// eases on `spring`:
//
//     Behavior on width {
//         NumberAnimation {
//             duration: Motion.spatial
//             easing.type: Easing.BezierSpline
//             easing.bezierCurve: Motion.spring
//         }
//     }
//
// The profile comes from Prefs.motion: spring (the mocks), current (today's
// 160 ms ease-out), slow (spring at a quarter speed, for review) and off.
// Off, or Prefs.reducedMotion, makes every duration 0 and `loops` false, so
// ambient loops (breathe, eq, caret) stop as well.
//
// QtQuick only. qmltestrunner loads this beside a stub Prefs, and an older
// Prefs without the motion keys reads as the default profile.
import QtQuick
import "lib/Spring.js" as Spring

QtObject {
    id: root

    // Milliseconds per profile. `curve` names the easing the profile uses.
    readonly property var profiles: ({
        spring: { spatial: 400, effects: 245, stagger: 80, curve: "spring" },
        current: { spatial: 160, effects: 90, stagger: 0, curve: "easeOut" },
        slow: { spatial: 1600, effects: 980, stagger: 320, curve: "spring" },
        off: { spatial: 0, effects: 0, stagger: 0, curve: "spring" }
    })

    readonly property var prefs: typeof Prefs === "undefined" ? null : Prefs
    readonly property string profile: {
        const p = prefs ? prefs.motion : undefined;
        return typeof p === "string" && Object.prototype.hasOwnProperty.call(profiles, p) ? p : "spring";
    }
    // No movement at all: the off profile, or reduced motion under any profile.
    readonly property bool reduced: profile === "off" || (prefs !== null && prefs.reducedMotion === true)
    // Ambient loops run only while this is true.
    readonly property bool loops: !reduced

    readonly property var active: profiles[profile]
    readonly property int spatial: reduced ? 0 : active.spatial
    readonly property int effects: reduced ? 0 : active.effects
    readonly property int stagger: reduced ? 0 : active.stagger
    // An outgoing layer's linear fade: half of effects, 123 ms on the spring profile.
    readonly property int exitFade: Math.round(effects / 2)

    // The curve for easing.bezierCurve under the active profile.
    readonly property var spring: active.curve === "easeOut" ? easeOut : springCurve

    // The spring shape whatever the profile (8 segments; see lib/Spring.js for
    // why it is not the 19-segment port of the mock's linear()).
    readonly property var springCurve: Spring.CURVE
    // One-cubic fallback, cubic-bezier(0.30, 0.553, 0.06, 1), max error 0.021.
    readonly property var springCubic: Spring.CUBIC
    // The current profile's ease-out, cubic-bezier(0.33, 1, 0.68, 1).
    readonly property var easeOut: Spring.EASE_OUT

    // Angular frequency for lib/Spring.js step(), matched to the durations above
    // so a retargeting value and a Behavior on the same duration move together.
    // Infinity when the duration is 0: step() snaps.
    readonly property real spatialOmega: Spring.omegaFor(spatial)
    readonly property real effectsOmega: Spring.omegaFor(effects)

    // A breathe loop's opacity `elapsed` ms in: 1 at 0, `low` half a period
    // later, back to 1 at `period`, on a cosine (the shape of the boards' two
    // InOutSine halves). The island's breathing marks (the working sparkle,
    // the recording dot) read it off a stepped Kit/CrewClock instead of
    // running a NumberAnimation, so they draw one frame per tick, on the same
    // frames as the bots (M3 review: a smooth loop redrew the island at the
    // display's refresh rate for as long as an agent worked).
    function breath(elapsed: real, period: real, low: real): real {
        if (!(period > 0)) return 1;
        const t = (((elapsed % period) + period) % period) / period;
        return low + (1 - low) * (1 + Math.cos(2 * Math.PI * t)) / 2;
    }
}
