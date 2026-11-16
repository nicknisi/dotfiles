import QtQuick
import Quickshell
import Quickshell.Io
import "launcher/voice"
import "lib/Dictation.js" as Dictation

// tests/voxtype-osd.sh: the daemon's dictation through a real VoiceSession
// (fixture state files, a fake voxtype and audio bridge), checked against
// lib/Dictation.js, the rule VoxtypeOsd.qml and the island share, and the
// card VoxtypeOsd draws, built in a plain window (offscreen Qt has no layer
// shell). Per step: what each bar mode would show.
ShellRoot {
    id: test
    property int step: 0
    VoiceSession { id: voice; command: Quickshell.env("HOME") + "/bin/voxtype" }
    readonly property string phase: Dictation.phase(voice)
    // What the popup (pill mode) and the island (island mode) would show.
    readonly property bool popup: Dictation.surface(phase, "pill") === "osd"
    readonly property bool island: Dictation.surface(phase, "island") === "island"
    FloatingWindow {
        implicitWidth: 440
        implicitHeight: 100
        VoxtypeCard {
            id: card
            anchors.fill: parent
            voice: voice
            phase: voice.daemonListening ? "listening" : "transcribing"
            label: phase === "listening" ? "Listening…" : "Finishing transcript…"
            shown: test.popup
        }
    }
    FileView { id: state; path: voice.statePath; atomicWrites: true }
    FileView { id: suppressed; path: voice.runtimeDir + "/voxtype/osd_suppressed"; atomicWrites: true }
    Process { id: remove; command: ["rm", "-f", suppressed.path] }

    function check(value, message) { if (!value) throw new Error(message) }
    // Every mode routes the same session to exactly one surface.
    function routes(shown, message) {
        test.check(test.popup === shown && test.island === shown, message + " (popup " + test.popup + ", island " + test.island + ")")
        test.check(Dictation.surface(test.phase, "full") === (shown ? "osd" : "") && Dictation.surface(test.phase, "rail") === (shown ? "osd" : ""), message + ": full and rail use the popup")
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step === 0 && voice.daemonState === "idle" && !voice.osdSuppressed) {
                    test.routes(false, "idle is hidden")
                    test.check(Dictation.clock(3400) === "0:03" && Dictation.clock(62000) === "1:02", "elapsed is m:ss")
                    state.setText("recording\n"); test.step++
                } else if (test.step === 1 && test.phase !== "" && voice.history.length) {
                    test.routes(true, "a daemon recording shows")
                    test.check(test.phase === "listening" && card.phase === "listening", "recording is listening")
                    test.check(voice.phase === "idle", "external recording remains externally owned")
                    test.check(voice.level > 0, "real bridge frames drive the waveform")
                    state.setText("streaming\n"); test.step++
                } else if (test.step === 2 && voice.daemonState === "streaming") {
                    test.routes(true, "streaming stays visible")
                    test.check(test.phase === "listening", "streaming is listening")
                    suppressed.setText("1\n"); test.step++
                } else if (test.step === 3 && voice.osdSuppressed) {
                    test.routes(false, "--no-osd hides both surfaces")
                    remove.running = true; test.step++
                } else if (test.step === 4 && !voice.osdSuppressed && !remove.running) {
                    test.routes(true, "removed suppression marker restores the overlay")
                    voice.phase = "starting"
                    test.routes(false, "launcher-owned recording has no second surface")
                    voice.phase = "transcribing"
                    test.routes(false, "launcher-owned transcription has no second surface")
                    voice.phase = "idle"
                    state.setText("transcribing\n"); test.step++
                } else if (test.step === 5 && voice.daemonState === "transcribing") {
                    test.routes(true, "transcribing shows")
                    test.check(test.phase === "transcribing" && card.label === "Finishing transcript…", "transcribing status")
                    state.setText("idle\n"); test.step++
                } else if (test.step === 6 && voice.daemonState === "idle") {
                    test.routes(false, "completion hides the overlay")
                    state.setText("unknown\n"); test.step++
                } else if (test.step === 7 && voice.daemonState === "unknown") {
                    test.routes(false, "unknown states stay hidden")
                    state.setText("recording\n"); test.step++
                } else if (test.step === 8 && test.phase !== "") {
                    remove.command = ["rm", "-f", state.path]; remove.running = true; test.step++
                } else if (test.step === 9 && voice.daemonState === "") {
                    test.routes(false, "missing daemon state hides the overlay")
                    test.check(voice.phase === "idle", "OSD never takes over recording or output")
                    console.log("VOXTYPE_OSD_PASS")
                    Qt.quit()
                }
            } catch (error) { console.error("VOXTYPE_OSD_FAIL:", error.message); Qt.quit() }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("VOXTYPE_OSD_FAIL: timeout at", test.step); Qt.quit() } }
}
