import QtQuick

// CrewClock.qml - one step clock for a group of pixel bots (M2 review).
//
// Every bot in a group (the rest pill's strip, the Crew panel's rows) reads
// its frame from the same `elapsed`, which moves only on this clock's tick, so
// the group changes in one go and the window draws at most one frame per
// tick. One Timer per bot drew a frame for each of them out of step: about
// 23 fps for crew-4, against M1's 0 at rest.
//
// The host sets `step` from CrewModel.clockStep(moods) (125 ms with a needs
// bot, 250 with only working ones, 0 when nothing moves) and `running` from
// whatever gates its loops (shown, Motion.loops, the session not idle).
// Stopping sets elapsed back to 0, so every bot returns to its baseline.
//
// QtQuick only, like the other Kit leaves (qmltestrunner loads it).
QtObject {
    id: clock

    property int step: 0
    property bool running: false
    // ms of ticks since the clock last started.
    property real elapsed: 0
    readonly property bool ticking: timer.running

    onRunningChanged: if (!running) elapsed = 0

    property Timer timer: Timer {
        interval: Math.max(1, clock.step)
        repeat: true
        running: clock.running && clock.step > 0
        onTriggered: clock.elapsed += clock.step
    }
}
