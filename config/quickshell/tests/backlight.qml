import Quickshell
import Quickshell.Io
import QtQuick

// Backlight (final audit): the level from sysfs through FileView polling, no
// process. tests/backlight.sh points Backlight.dir at a fake sysfs dir
// (BACKLIGHT_TEST_DIR, sed into the copy) and moves its `brightness` file
// while this runs; with BACKLIGHT_TEST_PHASE=none the dir has no backlight.
ShellRoot {
    id: test
    property var failures: []
    property int changes: 0
    property int step: 0
    readonly property string phase: Quickshell.env("BACKLIGHT_TEST_PHASE") || "live"
    readonly property string fake: Quickshell.env("BACKLIGHT_TEST_DIR") || ""

    function check(ok, message) {
        if (!ok) {
            failures.push(message);
            console.log("BACKLIGHT_TEST_FAIL " + message);
        }
    }

    Connections {
        target: Backlight
        function onChanged() { test.changes++; }
    }

    Process {
        id: writer
        property string level: ""
        command: ["sh", "-c", "printf '%s\\n' \"$1\" > \"$2/brightness\"", "sh", writer.level, test.fake]
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            const s = test.step++;
            if (test.phase === "none") {
                test.check(!Backlight.primed && Backlight.max === 1 && Backlight.fraction === 0, "no backlight: nothing read, fraction 0");
                finish();
                return;
            }
            if (s === 0) {
                test.check(Backlight.primed && Backlight.max === 200 && Backlight.value === 50, "the first reading: 50 of 200, primed: " + Backlight.value + "/" + Backlight.max);
                test.check(Math.abs(Backlight.fraction - 0.25) < 1e-9, "fraction 0.25");
                test.check(test.changes === 0, "the first reading is not a change");
                writer.level = "120";
                writer.running = true;
            } else if (s === 1) {
                test.check(Backlight.value === 120 && Math.abs(Backlight.fraction - 0.6) < 1e-9, "a write to brightness is picked up within a poll: " + Backlight.value);
                test.check(test.changes === 1, "one change signal: " + test.changes);
            } else if (s === 2) {
                test.check(test.changes === 1, "the same level again is no change: " + test.changes);
                finish();
            }
        }
        function finish() {
            running = false;
            console.log(test.failures.length === 0 ? "BACKLIGHT_TEST_PASS " + test.phase : "BACKLIGHT_TEST_FAIL " + test.phase);
            Qt.quit();
        }
    }
}
