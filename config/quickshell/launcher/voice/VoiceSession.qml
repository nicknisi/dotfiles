import QtQuick
import Quickshell
import Quickshell.Io

// Voice entry through the user's ordinary voxtype daemon. One recording
// at a time: `voxtype record start --file … --no-osd` (voxtype hides its own
// overlay for tools that draw their own), audio levels from voxtype's own
// bridge socket while listening, then `voxtype record stop --wait --json` to
// collect the transcript. Nothing runs while idle except the state watcher.
//
// phase: idle › starting › listening › transcribing › idle
Item {
  id: root
  property var host: null

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string transcriptPath: runtimeDir + "/keystroke-voice-" + Quickshell.processId + ".txt"
  readonly property string statePath: runtimeDir + "/voxtype/state"

  property bool detected: false          // a usable voxtype binary was found
  property string command: "/usr/bin/voxtype" // existing system CLI, injectable only for isolated tests
  property bool waitFile: false          // the CLI takes --wait-file; streaming sessions need it, see stop()
  property string version: ""
  property string daemonState: ""        // idle | recording | streaming | transcribing | "" (no daemon)
  readonly property bool daemonRunning: daemonState !== ""
  readonly property bool daemonListening: daemonState === "recording" || daemonState === "streaming"
  property bool osdSuppressed: true
  property string phase: "idle"          // idle | starting | listening | transcribing
  readonly property bool active: phase !== "idle"
  property real level: 0                 // smoothed loudness, 0..1
  property real peak: 0
  property bool vad: false
  property var history: []               // recent loudness samples, newest last
  property bool stopWhenStarted: false
  property bool cancelWhenStarted: false
  property double detectedAt: 0

  property string liveText: ""           // words so far, from the daemon's live transcript mirror (streaming engines)

  signal partial(string text)
  signal transcribed(string text)
  signal nothingHeard()
  signal failed(string message)

  // ------------------------------------------------------------ detection
  function refresh() {
    if (detectProc.running) return
    var now = Date.now()
    if (root.detectedAt && now - root.detectedAt < 30000) return
    root.detectedAt = now
    detectProc.running = true
  }
  // Use exactly the user's regular voxtype. In particular, do not revive an
  // old Keystroke-owned fork that may remain on disk from an earlier version.
  Process {
    id: detectProc
    command: ["sh", "-c", "b=\"$1\"; [ -x \"$b\" ] || exit 1; printf '%s\\n' \"$b\"; if \"$b\" record stop --help 2>/dev/null | grep -q -- --wait-file; then echo wait-file; else echo -; fi; exec \"$b\" --version", "keystroke", root.command]
    stdout: StdioCollector { id: detectOut }
    onExited: function(code) {
      var lines = String(detectOut.text || "").trim().split("\n")
      var ok = code === 0 && lines.length >= 3 && lines[2].length > 0
      root.detected = ok
      root.waitFile = ok && lines[1].trim() === "wait-file"
      root.version = ok ? lines[2].trim().replace(/^voxtype\s+/i, "") : ""
    }
  }
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    // voxtype truncates then writes this file; an empty intermediate read is
    // not an idle transition and must not stop an ongoing recording.
    onLoaded: { var state = String(text() || "").trim(); if (state) root.daemonState = state }
    onLoadFailed: root.daemonState = ""
    onFileChanged: reload()
  }
  // Honor --no-osd recordings, including recordings owned by another client.
  FileView {
    path: root.runtimeDir + "/voxtype/osd_suppressed"
    watchChanges: true
    printErrors: false
    onLoaded: root.osdSuppressed = true
    onLoadFailed: function(error) { root.osdSuppressed = error !== FileViewError.FileNotFound }
    onFileChanged: reload()
  }
  onDaemonListeningChanged: {
    root.history = []; root.level = 0; root.peak = 0; root.vad = false
  }
  // The daemon stops on its own at its max duration; follow it instead of
  // listening to a recording that no longer exists.
  onDaemonStateChanged: {
    if (root.phase !== "listening") return
    if (root.daemonState === "transcribing" || root.daemonState === "idle") root.stop()
    else if (!root.daemonState) { root.cancel(); root.failed("Voxtype daemon stopped") }
  }

  // -------------------------------------------------------------- session
  function start() {
    if (root.phase !== "idle") return false
    if (startProc.running || stopProc.running || fallbackRead.running || cancelProc.running || cleanupProc.running) {
      root.failed("Voice is finishing the previous recording; try again")
      return false
    }
    if (!root.runtimeDir || !root.detected) { root.failed("Voxtype or a private XDG_RUNTIME_DIR is unavailable"); return false }
    // Do not take over a recording started by the independent Copilot key.
    if (root.daemonState && root.daemonState !== "idle") { root.failed("Voxtype is already recording or transcribing"); return false }
    root.stopWhenStarted = false
    root.cancelWhenStarted = false
    root.history = []
    root.level = 0
    root.peak = 0
    root.vad = false
    root.liveText = ""
    root.phase = "starting"
    startProc.running = true
    return true
  }
  Process {
    id: startProc
    command: ["sh", "-c", "umask 077; rm -f \"$2\"; exec \"$1\" record start --file=\"$2\" --no-osd --no-auto-submit --no-smart-auto-submit", "keystroke", root.command, root.transcriptPath]
    stdout: StdioCollector { id: startOut }
    stderr: StdioCollector { id: startErr }
    onExited: function(code) {
      if (root.phase !== "starting") return
      if (code !== 0) {
        root.phase = "idle"
        var why = String(startErr.text || startOut.text || "").trim().split("\n").pop() || ("voxtype record start exited " + code)
        root.failed(root.daemonRunning ? why : "Voxtype daemon is not running (systemctl --user start voxtype)")
        return
      }
      if (root.cancelWhenStarted) { root.phase = "listening"; root.cancel(); return }
      root.phase = "listening"
      if (root.stopWhenStarted) root.stop()
    }
  }

  function stop() {
    if (root.phase === "starting") { root.stopWhenStarted = true; return }
    if (root.phase !== "listening") return
    root.phase = "transcribing"
    stopProc.running = true
  }
  // A streaming session consumes the --file override when it starts, so the
  // CLI cannot find the transcript on its own at stop time: name it.
  Process {
    id: stopProc
    command: root.waitFile ? [root.command, "record", "stop", "--wait", "--wait-file", root.transcriptPath, "--json", "--timeout", "90"]
                           : [root.command, "record", "stop", "--wait", "--json", "--timeout", "90"]
    stdout: StdioCollector { id: stopOut }
    stderr: StdioCollector { id: stopErr }
    onExited: function(code) {
      if (root.phase !== "transcribing") return
      var result = root.parseOutcome(stopOut.text)
      if (result && result.status === "ok" && String(result.text || "").trim()) {
        root.finish()
        root.transcribed(String(result.text).trim())
        return
      }
      if (code === 0 || code === 3) { fallbackRead.running = true; return }
      root.finish()
      root.failed(code === 4 ? "Transcription timed out" : (result && result.message) || String(stopErr.text || "").trim().split("\n").pop() || ("voxtype record stop exited " + code))
    }
  }
  // The daemon may have finished before we asked (auto-stop): the transcript
  // file is the source of truth then.
  Process {
    id: fallbackRead
    command: ["cat", root.transcriptPath]
    stdout: StdioCollector { id: fallbackOut }
    onExited: function(code) {
      if (root.phase !== "transcribing") return
      root.finish()
      var text = code === 0 ? String(fallbackOut.text || "").trim() : ""
      if (text) root.transcribed(text); else root.nothingHeard()
    }
  }
  function parseOutcome(raw) {
    var lines = String(raw || "").trim().split("\n")
    for (var i = lines.length - 1; i >= 0; i--) {
      var line = lines[i].trim()
      if (line.charAt(0) !== "{") continue
      try { return JSON.parse(line) } catch (e) { }
    }
    return null
  }

  function cancel() {
    if (root.phase === "starting") { root.cancelWhenStarted = true; return }
    if (root.phase === "idle") return
    // Retire the old CLI readers before allowing another recording. Otherwise
    // a cancelled --wait can deliver its result into the next session.
    root.phase = "idle"
    stopProc.running = false
    fallbackRead.running = false
    cancelProc.running = true
    root.finish()
  }

  function finish() {
    root.phase = "idle"
    root.level = 0
    root.peak = 0
    root.vad = false
    root.liveText = ""
    if (!cancelProc.running) cleanupProc.running = true
  }

  Process {
    id: cancelProc
    command: [root.command, "record", "cancel"]
    onExited: cleanupProc.running = true
  }
  Process { id: cleanupProc; command: ["rm", "-f", root.transcriptPath] }

  // ------------------------------------------------------------ live words
  // If a future/upstream daemon publishes a live transcript mirror, use it.
  // Current releases can simply leave this path absent: dictation still fills
  // the query from the final `record stop --wait` result. The poll complements
  // the watcher because mirror implementations replace the file by rename.
  readonly property string livePath: runtimeDir + "/voxtype/transcript"
  Loader {
    id: liveLoader
    active: root.phase === "listening"
    sourceComponent: FileView {
      path: root.livePath
      watchChanges: true
      printErrors: false
      onLoaded: root.liveUpdate(text())
      onFileChanged: reload()
    }
  }
  Timer { interval: 80; repeat: true; running: liveLoader.active; onTriggered: { if (liveLoader.item) liveLoader.item.reload() } }
  function liveUpdate(raw) {
    var t = String(raw || "").replace(/\s+/g, " ").trim()
    if (t === root.liveText) return
    root.liveText = t
    root.partial(t)
  }

  // ---------------------------------------------------------------- levels
  // voxtype's audio bridge prints one JSON frame per 10 ms while the daemon
  // records: {"peak":0.42,"rms":0.18,"vad":1,"ts_ms":…}. Only alive while listening.
  Process {
    id: bridge
    command: ["sh", "-c", "b=\"$(dirname \"$1\")/voxtype-audio-bridge\"; [ -x \"$b\" ] || b=voxtype-audio-bridge; RUST_LOG=error exec \"$b\"", "keystroke", root.command]
    // The same telemetry feeds the passive Copilot OSD. It never starts,
    // stops or redirects an external recording.
    running: root.phase === "listening" || (root.daemonListening && !root.osdSuppressed)
    stdout: SplitParser {
      onRead: function(line) {
        var frame = null
        try { frame = JSON.parse(String(line).trim()) } catch (e) { return }
        if (!frame || typeof frame.peak !== "number") return
        var loud = Math.min(1, frame.peak * 2.5)
        root.peak = loud
        root.vad = !!frame.vad
        root.level = Math.max(loud, root.level * 0.82)
        var next = root.history
        next.push(loud)
        if (next.length > 128) next.splice(0, next.length - 128)
        root.history = next
      }
    }
  }

  Component.onCompleted: root.refresh()
}
