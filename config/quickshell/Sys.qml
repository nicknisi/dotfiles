// Sys.qml - CPU and memory percentages, which the first bar declared but never
// filled in. One long-lived `sh` loop prints "<cpu> <mem>" every 2s and QML reads
// lines off stdout. Cheaper than respawning a process on a timer, and this build
// of Quickshell has no FileView in its Io qmltypes to poll /proc directly.
pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: 0
    property int mem: 0

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
            "  sleep 2; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/);
                if (parts.length !== 2) return;
                // First sample compares against prev_total=0, so it reports uptime
                // average rather than current load. Harmless, corrects in 2s.
                root.cpu = parseInt(parts[0]);
                root.mem = parseInt(parts[1]);
            }
        }
    }
}
