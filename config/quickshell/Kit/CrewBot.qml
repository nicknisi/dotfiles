import QtQuick
import qs
import "../lib/CrewModel.js" as CrewModel

// CrewBot.qml - one agent as a pixel bot (personal-looks 2.3, 3.3).
//
// The mood picks the sprite, colour and motion (lib/CrewModel.js MOODS):
//   needs    wave, `accent`, two hops of 0 / -2 / -4 / -2 (500 ms each), then
//            still for 3 s
//   working  awake (hat for a Riker worker), `fg`, bobs 0 / -1 / -2 / -1 over 1000 ms
//   asleep   sleep, `inkDim`, still
// Motion is a step animation, equal frames over `period` (the mock's CSS
// steps(2)), so nothing runs per frame. Offsets snap to whole device pixels,
// halves away from zero (PixelSprite.snap), so a bot never lands between them.
// `frames` and `period` can be overridden (the hail ring hops without the
// pause, vibes bobs at 800 ms).
//
// The clock: a host with several bots (CrewStrip, the Crew panel) passes one
// shared Kit/CrewClock, and every bot reads its frame from that clock's
// `elapsed`, so the group moves on one tick and the window draws one frame
// per tick. A lone bot (the hail ring, vibes) leaves `clock` null and runs its
// own Timer. Either way the loop stops while the bot is hidden (its layer
// gone), while `animated` is false, and whenever Motion.loops is false
// (reduced motion, the off profile), and the bot rests on its baseline.
//
// phase starts the loop that many frames in: hosts give every second working
// bot 2 (the mock's -0.45 s on the bob), so neighbours do not bob in step.
//
// The bot is `size` square and draws from its top; hosts leave headroom for
// the hop (CrewStrip bottom-aligns bots in an 18 px row). Accessible.ignored
// by default; a host that lists bots names each one ("{name}, {state}").
Item {
    id: bot

    property string mood: "working"
    property bool riker: false
    property real size: 16
    property real dpr: 1
    property int phase: 0
    // Overrides for the vibes card (an accent bot bobbing at 800 ms) and the hail ring.
    property color tint: bot.mood === "needs" ? Tokens.accent : bot.mood === "asleep" ? Tokens.inkDim : Tokens.fg
    property int period: bot.spec.period
    property var frames: bot.spec.frames
    property bool animated: true
    // A shared Kit/CrewClock, or null for the bot's own timer.
    property var clock: null

    readonly property var spec: CrewModel.MOODS[bot.mood] ?? CrewModel.MOODS.asleep
    readonly property string spriteName: bot.mood === "needs" ? "wave" : bot.mood === "asleep" ? "sleep" : bot.riker ? "hat" : "awake"
    readonly property int frameCount: Math.max(1, (bot.frames || []).length)
    readonly property int frameMs: Math.max(1, Math.round(bot.period / bot.frameCount))
    // Whether this bot's loop may run at all; the clock decides when it ticks.
    readonly property bool loops: bot.animated && bot.visible && Motion.loops && bot.period > 0 && bot.frameCount > 1
    readonly property bool moving: bot.loops && (bot.clock ? bot.clock.running && bot.clock.step > 0 : stepper.running)
    readonly property int frame: !bot.moving ? 0 : bot.clock ? (Math.floor(bot.clock.elapsed / bot.frameMs) + bot.phase) % bot.frameCount : own.frame
    readonly property real offset: sprite.snap(bot.frames[bot.frame % bot.frameCount] ?? 0, bot.dpr)
    readonly property alias sprite: sprite

    implicitWidth: sprite.implicitWidth
    implicitHeight: sprite.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Accessible.ignored: true

    PixelSprite {
        id: sprite
        y: bot.offset
        rows: CrewModel.SPRITES[bot.spriteName]
        size: bot.size
        dpr: bot.dpr
        color: bot.tint
        Behavior on color {
            ColorAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }

    // The lone bot's own loop, frame counted from the phase.
    QtObject {
        id: own
        property int frame: 0
    }
    Timer {
        id: stepper
        interval: bot.frameMs
        repeat: true
        running: bot.clock === null && bot.loops
        onRunningChanged: own.frame = bot.phase % bot.frameCount
        onTriggered: own.frame = (own.frame + 1) % bot.frameCount
    }
    onMoodChanged: own.frame = bot.phase % bot.frameCount
}
