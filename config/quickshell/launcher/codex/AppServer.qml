import QtQuick
import Quickshell.Io
import "Policy.js" as Policy

Item {
  id: root
  property var command: ["bash", decodeURIComponent(Qt.resolvedUrl("../helpers/codex-start.sh").toString().replace(/^file:\/\//, ""))]
  property bool ready: false
  property bool starting: false
  property bool keepBusy: false
  property bool expectedExit: false
  property bool restartRequested: false
  property string error: ""
  property string diagnostic: ""
  property int sequence: 0
  property var pending: ({})
  property var configuration: ({})
  property var models: []
  property string accountState: ""
  signal event(string method, var params)
  signal serverRequest(var id, string method, var params)
  signal disconnected(string message)
  signal stopped()

  function ensure() {
    idle.restart()
    if (proc.running && expectedExit) { restartRequested = true; return }
    if (ready || starting || proc.running) return
    error = ""; diagnostic = ""; starting = true; expectedExit = false
    proc.running = true
    startup.restart()
  }
  function send(value) { if (proc.running) proc.write(JSON.stringify(value) + "\n") }
  function request(method, params, callback, timeout) {
    var id = ++sequence
    var copy = Object.assign({}, pending)
    copy[id] = { callback: callback, expires: Date.now() + (timeout || 30000) }
    pending = copy
    send({id: id, method: method, params: params || {}})
    idle.restart()
    return id
  }
  function respond(id, result) { send({id: id, result: result}) }
  function reject(id, message) { send({id: id, error: {code: -32601, message: message}}) }
  function receive(line) {
    if (line.length > 8 * 1024 * 1024) { fail("Codex sent an oversized message"); return }
    var msg
    try { msg = JSON.parse(line) } catch (_) { fail("Invalid response from Codex"); return }
    if (msg.method) {
      if (msg.id !== undefined) serverRequest(msg.id, msg.method, msg.params || {})
      else event(msg.method, msg.params || {})
    } else if (msg.id !== undefined && pending[msg.id]) {
      var entry = pending[msg.id], copy = Object.assign({}, pending)
      delete copy[msg.id]; pending = copy
      entry.callback(msg.result, msg.error || null)
    }
  }
  function fail(message) {
    error = message
    ready = false; starting = false
    startup.stop()
    var callbacks = pending; pending = ({})
    for (var id in callbacks) callbacks[id].callback(null, {message: message})
    disconnected(message)
    expectedExit = true; proc.running = false
  }
  function shutdown() {
    restartRequested = false
    expectedExit = true; ready = false; starting = false
    startup.stop(); idle.stop()
    var callbacks = pending; pending = ({})
    for (var id in callbacks) callbacks[id].callback(null, {message: "Codex connection closed"})
    proc.running = false
  }
  Process {
    id: proc
    command: root.command
    stdinEnabled: true
    onStarted: root.request("initialize", {clientInfo: {name: "keystroke", title: "Keystroke", version: "0.2.0"}, capabilities: {experimentalApi: true}}, function(result, error) {
      if (error) { root.fail(Policy.plainError(error)); return }
      root.send({method: "initialized"})
      root.request("config/read", {includeLayers: false}, function(result, error) {
        if (error) { root.fail(Policy.plainError(error)); return }
        root.configuration = result.config || {}
        root.request("model/list", {includeHidden: false}, function(result, error) {
          if (error) { root.fail(Policy.plainError(error)); return }
          root.models = result.data || []
          root.request("account/read", {refreshToken: false}, function(result, error) {
            if (error) { root.fail(Policy.plainError(error)); return }
            root.accountState = result.account ? "Signed in" : "Sign in with codex login"
            root.starting = false; startup.stop(); root.ready = true
          })
        })
      })
    })
    stdout: SplitParser { onRead: data => root.receive(data) }
    stderr: SplitParser { onRead: data => { root.diagnostic = (root.diagnostic + "\n" + data).slice(-3000) } }
    onExited: function(code) {
      if (root.expectedExit) {
        var restart = root.restartRequested; root.restartRequested = false
        root.stopped()
        if (restart) Qt.callLater(root.ensure)
        return
      }
      root.fail(code === 65 ? "Codex version mismatch. Keystroke requires " + Policy.VERSION : "Codex stopped. Your conversation is saved; reopen it to continue.")
    }
  }
  Timer { id: startup; interval: 45000; onTriggered: root.fail("Codex startup timed out. Check your login and connection.") }
  Timer { interval: 1000; repeat: true; running: proc.running && Object.keys(root.pending).length > 0; onTriggered: {
    var now = Date.now()
    for (var id in root.pending) if (root.pending[id].expires < now) { root.fail("Codex request timed out. The request was not retried."); break }
  } }
  Timer { id: idle; interval: 600000; onTriggered: { if (root.keepBusy || Object.keys(root.pending).length) restart(); else root.shutdown() } }
  Component.onDestruction: shutdown()
}
