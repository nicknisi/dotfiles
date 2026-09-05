pragma Singleton
// Backlight.qml - current screen brightness as a 0..1 fraction.
//
// Deliberately *watches* /sys instead of being told by a keybind: media-keys.lua
// shells out to brightnessctl, so anything else that moves the backlight (the
// power daemon, a lid event, brightnessctl typed by hand) still moves the OSD.
// That keeps hypr/media-keys.lua untouched.
//
// The loop only echoes when the value actually changes, so QML wakes up on real
// events rather than 7 times a second.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int value: 0
    property int max: 1
    readonly property real fraction: max > 0 ? value / max : 0

    // False until the first reading lands, so the OSD does not flash on login.
    property bool primed: false

    signal changed()

    Process {
        running: true
        command: ["sh", "-c",
            "d=/sys/class/backlight/intel_backlight; " +
            "m=$(cat $d/max_brightness); " +
            "prev=''; " +
            "while :; do " +
            "  v=$(cat $d/brightness); " +
            "  if [ \"$v\" != \"$prev\" ]; then echo \"$v $m\"; prev=$v; fi; " +
            "  sleep 0.15; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/);
                if (parts.length !== 2) return;

                root.value = parseInt(parts[0]);
                root.max = parseInt(parts[1]);

                if (root.primed) root.changed();
                else root.primed = true;
            }
        }
    }
}
