pragma Singleton
// Interrupt.qml - what the shell is currently shouting about.
//
// The capsule is the only thing on screen that speaks, so everything that used
// to open a window of its own files through here instead and the capsule takes
// the shape of whichever message is live. Osd.qml was that window; it is gone.
//
// One slot, last writer wins. Pressing volume-up during a brightness change
// shows volume, because the newest event is the one you caused.
import Quickshell
import QtQuick

Singleton {
    id: root

    // "" | "volume" | "mic" | "brightness"
    property string kind: ""
    readonly property bool active: root.kind !== ""

    // PipeWire binds the sink a beat after login and the backlight is read at
    // startup, both of which look exactly like a change. Nothing speaks for the
    // first two seconds, otherwise the capsule flinches on every login.
    property bool primed: false
    Timer { interval: 2000; running: true; onTriggered: root.primed = true }

    Timer { id: hide; interval: 1600; onTriggered: root.kind = "" }

    function show(which: string): void {
        if (!root.primed) return;
        root.kind = which;
        hide.restart();
    }

    // Watching a bound property and reacting to its change signal is less
    // brittle than Connections with hand-written signal handler names.
    property real volume: Audio.volume
    onVolumeChanged: root.show("volume")

    property bool muted: Audio.muted
    onMutedChanged: root.show("volume")

    property bool micMuted: Audio.micMuted
    onMicMutedChanged: root.show("mic")

    property real brightness: Backlight.fraction
    onBrightnessChanged: root.show("brightness")

    // ---- what the capsule draws -------------------------------------------
    // Shape and wording live with the state that drives them. Colour stays in
    // the bar, where Theme is already in scope.
    readonly property string glyph: {
        if (root.kind === "brightness")
            return "\u{f05a8}";                                  // md white-balance-sunny
        if (root.kind === "mic")
            return Audio.micMuted ? "\uf131" : "\uf130";   // fa microphone-slash / microphone
        return Audio.muted ? "\uf026" : "\uf028";           // fa volume-off / volume-up
    }

    // The mic is the one message with no quantity behind it, so it is the one
    // that draws no meter.
    readonly property bool metered: root.kind !== "mic"

    readonly property real fraction: {
        if (root.kind === "brightness")
            return Backlight.fraction;
        return Audio.muted ? 0 : Audio.volume;
    }

    readonly property string label: {
        if (root.kind === "mic")
            return Audio.micMuted ? "mic off" : "mic on";
        return `${Math.round(root.fraction * 100)}%`;
    }
}
