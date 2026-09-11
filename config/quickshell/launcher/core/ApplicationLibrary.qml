import QtQuick
import Quickshell
import Quickshell.Io

// Keep the upstream AppLibrary contract, with Quickshell's native desktop data.
Item {
  id: root
  // Still assigned by the upstream host. Neither enables a second library.
  property var hostShell: null
  property string omarchyPath: ""
  readonly property var sharedLibrary: null
  readonly property var library: root
  readonly property var apps: DesktopEntries.applications.values
  property string errorMessage: ""

  function entryName(entry) { return String(entry.name || entry.id || "Application") }
  function entrySubtext(entry) { return String(entry.genericName || entry.comment || "") }
  function iconSource(icon) { return icon ? Quickshell.iconPath(String(icon), true) : "" }
  function iconFor(entry) {
    if (typeof entry === "string") entry = DesktopEntries.byId(entry)
    return entry ? root.iconSource(entry.icon) : ""
  }
  function refreshIcons() { root.appsChanged() }

  function sortedEntries(query) {
    var needle = String(query || "").toLowerCase(), out = []
    for (var i = 0; i < root.apps.length; i++) {
      var entry = root.apps[i]
      if (entry.noDisplay || !entry.command || !entry.command.length) continue
      if (needle && root.entryName(entry).toLowerCase().indexOf(needle) < 0) continue
      out.push({ entry: entry })
    }
    out.sort(function(a, b) { return root.entryName(a.entry).localeCompare(root.entryName(b.entry)) || String(a.entry.id).localeCompare(String(b.entry.id)) })
    return out
  }

  function launchContext(entry) {
    var command = ["uwsm-app", "--"]
    if (entry.runInTerminal) command.push("ghostty", "-e")
    for (var i = 0; i < entry.command.length; i++) command.push(String(entry.command[i]))
    var context = { command: command }
    if (entry.workingDirectory) context.workingDirectory = String(entry.workingDirectory)
    return context
  }
  function fail(message) {
    root.errorMessage = message
    Quickshell.execDetached(["notify-send", "--app-name=Launcher", "--", "Application error", message])
    return false
  }
  function launch(id, name) {
    var entry = DesktopEntries.byId(String(id))
    if (!entry || entry.noDisplay || !entry.command.length) return root.fail("Application is no longer available")
    root.errorMessage = ""
    Quickshell.execDetached(root.launchContext(entry))
    return true
  }

  // The host calls this only after its uninstall confirmation. Inspect package
  // ownership first, then open the package manager's interactive confirmation.
  function remove(id, name) {
    if (removal.running) return false
    if (!DesktopEntries.byId(String(id))) return root.fail("Application is no longer available")
    root.errorMessage = ""
    removal.command = ["luajit", decodeURIComponent(Qt.resolvedUrl("../helpers/remove-app.lua").toString().replace(/^file:\/\//, "")), "--", String(id)]
    removal.running = true
    return true
  }
  Process {
    id: removal
    property var result: null
    onStarted: result = null
    stdout: StdioCollector {
      onStreamFinished: {
        try { removal.result = JSON.parse(text) } catch (e) { removal.result = null }
      }
    }
    onExited: function(code) {
      var result = removal.result
      if (code !== 0 || !result || !result.argv) { root.fail(result && result.error ? result.error : "Could not inspect application ownership"); return }
      Quickshell.execDetached(["uwsm-app", "--", "ghostty", "-e"].concat(result.argv))
    }
  }
}
