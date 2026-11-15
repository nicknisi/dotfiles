import Quickshell.Io
import QtQuick

// PickerRun.qml - the picker's Enter running bin/theme (PLAN M7,
// launcher-pickers 7.4: "surface an error if `theme` exited non-zero").
// ThemePicker.qml owns one; tests/check.qml runs one against a command that
// fails.
//
// run(argv) starts one Process per call, so two quick Enters overlap as
// they did detached, and ended(argv, code, output) reports each: the exit
// code, and for a failure the last three lines bin/theme printed. A small sh
// wrapper sends bin/theme's output to a temp file, not into a pipe to this
// shell: if the shell reloads or quits mid-run, bin/theme still finishes
// rather than dying of SIGPIPE half applied, and what it leaves running
// (hyprpaper, `theme thumbs`) holds no pipe open.
QtObject {
    id: runner

    signal ended(var argv, int code, string output)

    readonly property string script: 'log=$(mktemp "${TMPDIR:-/tmp}/theme-run.XXXXXX") || log=/dev/null; "$0" "$@" >"$log" 2>&1; code=$?; [ "$code" -eq 0 ] || tail -n 3 "$log"; [ "$log" = /dev/null ] || rm -f "$log"; exit "$code"'

    function run(argv) {
        if (!Array.isArray(argv) || argv.length === 0) return;
        const job = runner.jobComponent.createObject(runner, { argv: argv });
        if (job) job.running = true;
    }

    property Component jobComponent: Component {
        Process {
            id: run
            property var argv: []
            property int code: -1
            property bool drained: false
            property string output: ""
            command: ["sh", "-c", runner.script].concat(run.argv)
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    run.output = text.trim();
                    run.drained = true;
                    run.finish();
                }
            }
            onExited: exitCode => {
                run.code = exitCode;
                run.finish();
            }
            // Both the exit and the end of its output, in either order.
            function finish() {
                if (run.code < 0 || !run.drained) return;
                runner.ended(run.argv, run.code, run.output);
                run.destroy();
            }
        }
    }
}
