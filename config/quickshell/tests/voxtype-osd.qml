import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "launcher/voice"

ShellRoot {
    id: test
    property int step: 0
    VoiceSession { id: voice; command: Quickshell.env("HOME") + "/bin/voxtype" }
    VoxtypeOsd { id: osd; voice: voice }
    FileView { id: state; path: voice.statePath; atomicWrites: true }
    FileView { id: suppressed; path: voice.runtimeDir + "/voxtype/osd_suppressed"; atomicWrites: true }
    Process { id: remove; command: ["rm", "-f", suppressed.path] }

    function check(value, message) { if (!value) throw new Error(message) }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step === 0 && voice.daemonState === "idle" && !voice.osdSuppressed) {
                    test.check(!osd.visible, "idle is hidden")
                    test.check(osd.mask.width === 0 && osd.mask.height === 0, "empty pointer input region")
                    state.setText("recording\n"); test.step++
                } else if (test.step === 1 && osd.visible && voice.history.length) {
                    test.check(voice.phase === "idle", "external recording remains externally owned")
                    test.check(osd.phase === "listening" && voice.level > 0, "real bridge frames drive the waveform")
                    state.setText("streaming\n"); test.step++
                } else if (test.step === 2 && voice.daemonState === "streaming") {
                    test.check(osd.visible && osd.phase === "listening", "streaming stays visible")
                    suppressed.setText("1\n"); test.step++
                } else if (test.step === 3 && voice.osdSuppressed) {
                    test.check(!osd.visible, "--no-osd hides the overlay")
                    remove.running = true; test.step++
                } else if (test.step === 4 && !voice.osdSuppressed && !remove.running) {
                    test.check(osd.visible, "removed suppression marker restores the overlay")
                    voice.phase = "starting"
                    test.check(!osd.visible, "launcher-owned recording has no second popup")
                    voice.phase = "transcribing"
                    test.check(!osd.visible, "launcher-owned transcription has no second popup")
                    voice.phase = "idle"
                    state.setText("transcribing\n"); test.step++
                } else if (test.step === 5 && voice.daemonState === "transcribing") {
                    test.check(osd.visible && osd.label === "Finishing transcript…", "transcribing status")
                    state.setText("idle\n"); test.step++
                } else if (test.step === 6 && voice.daemonState === "idle") {
                    test.check(!osd.visible, "completion hides the overlay")
                    state.setText("unknown\n"); test.step++
                } else if (test.step === 7 && voice.daemonState === "unknown") {
                    test.check(!osd.visible, "unknown states stay hidden")
                    state.setText("recording\n"); test.step++
                } else if (test.step === 8 && osd.visible) {
                    remove.command = ["rm", "-f", state.path]; remove.running = true; test.step++
                } else if (test.step === 9 && voice.daemonState === "") {
                    test.check(!osd.visible, "missing daemon state hides the overlay")
                    test.check(voice.phase === "idle", "OSD never takes over recording or output")
                    console.log("VOXTYPE_OSD_PASS")
                    Qt.quit()
                }
            } catch (error) { console.error("VOXTYPE_OSD_FAIL:", error.message); Qt.quit() }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("VOXTYPE_OSD_FAIL: timeout at", test.step); Qt.quit() } }
}
