pragma Singleton
// Backlight.qml - current screen brightness as a 0..1 fraction.
//
// Deliberately *watches* /sys instead of being told by a keybind: media-keys.lua
// shells out to brightnessctl, so anything else that moves the backlight (the
// power daemon, a lid event, brightnessctl typed by hand) still moves the OSD.
// That keeps hypr/media-keys.lua untouched.
//
// sysfs sends no inotify event when the level moves, so it polls: a Timer
// re-reads `brightness` every 150 ms through a FileView (the read runs off the
// GUI thread), and `value` only changes on a real change, so QML wakes up on
// real events. No process: the `sh` loop this replaced forked `sleep` and
// `cat` about 7 times a second, the only spawns left at rest (final audit).
// Without a backlight (no max_brightness) nothing polls.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int value: 0
    property int max: 1
    readonly property real fraction: max > 0 ? value / max : 0

    // False until the first reading lands, so the OSD does not flash on login.
    property bool primed: false

    signal changed()

    readonly property string dir: "/sys/class/backlight/intel_backlight"

    FileView {
        id: maxFile
        path: root.dir + "/max_brightness"
        printErrors: false
        onLoaded: {
            const m = parseInt(maxFile.text());
            if (!(m > 0)) return;
            root.max = m;
            poll.running = true;
        }
    }

    FileView {
        id: levelFile
        path: root.dir + "/brightness"
        printErrors: false
        onLoaded: {
            const v = parseInt(levelFile.text());
            if (isNaN(v)) return;
            if (!root.primed) {
                root.value = v;
                root.primed = true;
                return;
            }
            if (v === root.value) return;
            root.value = v;
            root.changed();
        }
    }

    Timer {
        id: poll
        interval: 150
        repeat: true
        onTriggered: levelFile.reload()
    }
}
