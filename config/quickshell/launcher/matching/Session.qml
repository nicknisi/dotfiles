import QtQuick
import Quickshell.Io

// One resident worker, one request in flight, and only the latest queued query.
Item {
  id: root
  enabled: false
  property string model: "small"
  property bool setupRequested: false
  property var command: ["luajit", decodeURIComponent(Qt.resolvedUrl("../helpers/matching-start.lua").toString().replace(/^file:\/\//, "")), "--model", model].concat(setupRequested ? [] : ["--offline"])
  property bool ready: false
  property bool starting: false
  property bool stopping: false
  property bool failed: false
  property string status: "Model unloaded"
  property string error: ""
  property int serial: 0
  property int inFlight: 0
  property string requestedKey: ""
  property string resultKey: ""
  property var matches: []
  property var queued: null
  property string sentCatalog: ""
  readonly property bool loaded: ready
  readonly property bool busy: starting || inFlight !== 0 || queued !== null
  signal changed()
  onStatusChanged: Qt.callLater(root.changed)

  function configure() {
    root.shutdown()
    root.failed = false; root.error = ""; root.setupRequested = false
    root.changed()
  }
  onEnabledChanged: configure()
  onModelChanged: configure()

  function shutdown() {
    root.serial++; root.queued = null; root.inFlight = 0
    root.requestedKey = ""; root.resultKey = ""; root.matches = []
    root.ready = false; root.starting = false; root.sentCatalog = ""
    root.status = "Model unloaded"
    startup.stop(); response.stop(); idle.stop(); delay.stop()
    root.stopping = proc.running
    proc.running = false
  }
  function retry() {
    root.configure()
    if (root.enabled) {
      root.setupRequested = true // Retry is the explicit setup/download action.
      idle.restart()
      root.queued = { key: "warm", query: "", rows: [] }
      root.sendLatest()
    }
  }
  function cancelRequest() {
    root.requestedKey = ""; root.queued = null; root.resultKey = ""; root.matches = []
    delay.stop()
  }
  // catalogKey identifies the rows; the host computes it once per catalog so
  // an unchanged catalog is never serialized again just to be compared.
  function submit(key, query, rows, catalogKey) {
    if (!root.enabled || root.failed) return
    if (root.requestedKey === key) return
    idle.restart()
    root.requestedKey = key; root.resultKey = ""; root.matches = []
    root.queued = { key: key, query: query, rows: rows, catalogKey: catalogKey === undefined ? JSON.stringify(rows) : String(catalogKey) }
    delay.restart()
  }
  function unloadIdle() {
    // Keep the tiny ID/score result for the unchanged visible query. Clearing
    // its key here would cause the status refresh to immediately reload a model.
    root.ready = false; root.sentCatalog = ""; root.stopping = proc.running
    proc.running = false; root.status = "Model unloaded"
  }
  function sendLatest() {
    if (!root.enabled || root.failed || !root.queued || root.stopping) return
    if (!proc.running) {
      root.starting = true; root.status = "Preparing matching model"; root.error = ""
      proc.running = true; startup.restart(); return
    }
    if (!root.ready || root.inFlight) return
    var job = root.queued; root.queued = null
    var id = ++root.serial
    var message = { id: id, query: job.query }
    if (job.catalogKey !== root.sentCatalog) { message.rows = job.rows; root.sentCatalog = job.catalogKey }
    root.inFlight = id
    root.flightKey = job.key
    proc.write(JSON.stringify(message) + "\n")
    response.restart()
  }
  property string flightKey: ""
  function fail(message) {
    root.shutdown(); root.failed = true; root.error = message
    root.status = "Unavailable"; root.changed()
  }
  function receive(line) {
    if (root.stopping || !root.enabled) return
    var msg
    try { msg = JSON.parse(line) } catch (_) { root.fail("Invalid response from Smart Match"); return }
    if (msg.type === "status") { root.status = String(msg.message); return }
    if (msg.type === "error") { root.fail(String(msg.message)); return }
    if (msg.type === "ready") {
      root.ready = true; root.starting = false; root.status = "Ready"; startup.stop()
      root.sendLatest(); root.changed(); return
    }
    if (msg.type !== "result" || msg.id !== root.inFlight) return
    response.stop(); root.inFlight = 0
    if (root.flightKey === root.requestedKey && !root.queued) {
      root.resultKey = root.flightKey; root.matches = msg.matches || []; root.changed()
    }
    root.sendLatest()
  }
  Process {
    id: proc
    command: root.command
    stdinEnabled: true
    stdout: SplitParser { onRead: data => root.receive(data) }
    stderr: SplitParser { onRead: data => console.log("keystroke matching:", data) }
    onExited: {
      var expected = root.stopping
      root.stopping = false
      if (!expected && !root.failed) root.fail("Matching helper stopped; retry in Keystroke Settings")
      if (expected && root.queued && root.enabled) Qt.callLater(root.sendLatest)
    }
  }
  // The host already debounces keystrokes; this only folds a burst of
  // refreshes into one request. The helper answers in a few milliseconds.
  Timer { id: delay; interval: 10; onTriggered: root.sendLatest() }
  Timer { id: startup; interval: 300000; onTriggered: root.fail("Matching setup timed out; check your connection and retry") }
  Timer { id: response; interval: 5000; onTriggered: root.fail("Smart Match timed out; ordinary search is still available") }
  Timer { id: idle; interval: 120000; onTriggered: { if (root.busy) restart(); else root.unloadIdle() } }
  Component.onDestruction: shutdown()
}
