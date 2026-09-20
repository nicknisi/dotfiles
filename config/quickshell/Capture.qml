pragma Singleton
// Capture.qml - is bin/capture recording the screen right now?
//
// bin/capture writes wf-recorder's pid to $XDG_RUNTIME_DIR/capture-wf-recorder.pid
// and removes it on stop. It also pings `qs ipc call capture refresh` at both
// points, because a FileView cannot watch a file that does not exist yet, so
// the first recording after a shell start would otherwise go unnoticed. While
// a recording runs, the pid is poked every few seconds so a wf-recorder that
// died on its own does not leave the glyph lit.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int pid: 0
    readonly property bool recording: pid > 0
    readonly property string pidPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/capture-wf-recorder.pid"

    function refresh(): void { pidFile.reload() }
    function stop(): void { Quickshell.execDetached(["capture", "record", "stop"]) }

    IpcHandler {
        target: "capture"
        function refresh(): void { root.refresh() }
    }

    FileView {
        id: pidFile
        path: root.pidPath
        watchChanges: true
        printErrors: false // absent is the normal state
        onFileChanged: reload()
        onLoaded: root.pid = parseInt(text().trim()) || 0
        onLoadFailed: root.pid = 0
    }

    Process {
        id: alive
        command: ["kill", "-0", String(root.pid)]
        onExited: code => { if (code !== 0) root.pid = 0 }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.recording
        onTriggered: if (!alive.running) alive.running = true
    }
}
