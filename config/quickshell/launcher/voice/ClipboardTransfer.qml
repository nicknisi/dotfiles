import QtQuick
import Quickshell.Io

// Copy completes before the palette closes. Only then allow 100 ms for focus
// restoration and dispatch a paste shortcut. Text travels over stdin, not shell.
Item {
  id: root
  property var copyCommand: ["wl-copy"]
  property var pasteCommand: ["wtype", "-M", "shift", "-k", "Insert", "-m", "shift"]
  property bool busy: false
  property bool pasteAfterCopy: false
  property string payload: ""
  signal copied()
  signal completed()
  signal failed(string message)

  function submit(text, paste) {
    if (root.busy || copyProc.running || pasteProc.running || !String(text || "").trim()) return false
    root.busy = true
    root.payload = String(text)
    root.pasteAfterCopy = paste === true
    copyProc.stdinEnabled = true
    copyProc.running = true
    deadline.restart()
    return true
  }
  function cancel() {
    root.busy = false
    root.payload = ""
    root.pasteAfterCopy = false
    delay.stop(); deadline.stop()
    copyProc.running = false
    pasteProc.running = false
  }
  function fail(message) { root.cancel(); root.failed(message) }
  Process {
    id: copyProc
    command: root.copyCommand
    onStarted: { write(root.payload); root.payload = ""; stdinEnabled = false }
    onExited: function(code) {
      if (!root.busy) return
      if (code !== 0) { root.fail("Could not copy dictation to the clipboard"); return }
      root.copied()
      if (!root.busy) return
      if (root.pasteAfterCopy) delay.restart()
      else { root.busy = false; deadline.stop(); root.completed() }
    }
  }
  Timer { id: delay; interval: 100; onTriggered: pasteProc.running = true }
  Process {
    id: pasteProc
    command: root.pasteCommand
    onExited: function(code) {
      if (!root.busy) return
      root.busy = false; deadline.stop()
      if (code !== 0) root.failed("Text copied, but the paste shortcut failed")
      else root.completed()
    }
  }
  Timer { id: deadline; interval: 5000; onTriggered: root.fail("Clipboard operation timed out") }
}
