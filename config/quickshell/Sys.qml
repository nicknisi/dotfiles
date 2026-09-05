pragma Singleton
// Sys.qml - CPU and memory percentages, which the first bar declared but never
// filled in. One long-lived `sh` loop prints "<cpu> <mem>" every second and QML
// reads lines off stdout. Cheaper than respawning a process on a timer, and this
// build of Quickshell has no FileView in its Io qmltypes to poll /proc directly.
//
// The interval was 2s when this fed two numbers. The bar draws a sparkline off
// it now, and a strip that only steps every other second reads as frozen, so it
// samples every second. The cost is two awk forks a second against /proc, which
// is the knob to turn back if that ever matters.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: 0
    property int mem: 0

    // A rolling window for the bar's sparklines. 16 samples at the interval
    // below is a quarter minute of history: long enough to show a build
    // starting, short enough to still feel live, narrow enough that two of them
    // side by side do not dominate the bar.
    readonly property int samples: 16
    // Pre-filled so the strip has its full width from the first frame instead of
    // growing sideways and shoving the modules beside it along. Filled in the
    // initialiser rather than from Component.onCompleted, which needs an attached
    // object a Quickshell Singleton does not carry.
    property var cpuHistory: new Array(root.samples).fill(0)
    property var memHistory: new Array(root.samples).fill(0)

    // QML notices a new array, not a push into the old one.
    function pushSample(series, value) {
        const out = series.slice(-(root.samples - 1));
        out.push(value);
        return out;
    }

    Process {
        running: true
        command: ["sh", "-c",
            "prev_total=0; prev_idle=0; " +
            "while :; do " +
            "  set -- $(awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5; exit}' /proc/stat); " +
            "  total=$1; idle=$2; " +
            "  d_total=$((total - prev_total)); d_idle=$((idle - prev_idle)); " +
            "  prev_total=$total; prev_idle=$idle; " +
            "  c=0; [ \"$d_total\" -gt 0 ] && c=$(( (100 * (d_total - d_idle)) / d_total )); " +
            "  m=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d\", (t-a)*100/t}' /proc/meminfo); " +
            "  echo \"$c $m\"; " +
            "  sleep 1; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/);
                if (parts.length !== 2) return;
                // First sample compares against prev_total=0, so it reports uptime
                // average rather than current load. Harmless, corrects in 1s.
                root.cpu = parseInt(parts[0]);
                root.mem = parseInt(parts[1]);
                root.cpuHistory = root.pushSample(root.cpuHistory, root.cpu);
                root.memHistory = root.pushSample(root.memHistory, root.mem);
            }
        }
    }
}
