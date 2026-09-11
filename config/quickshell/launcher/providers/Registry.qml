import QtQuick
import Quickshell
import Quickshell.Io
import "." as Providers
import "../core/Patterns.js" as Patterns
import "../core/Extensions.js" as ExtensionsModel

// Bundled providers and community services share the upstream provider API.
// Each extension gets its own object tree and legacy context properties.
Item {
  id: root
  property var host: null
  property var entries: []     // [{ key, provider, source, pluginId, name, patterns }]
  property var problems: []    // [{ pluginId, message }]
  property var manifests: ({}) // plugin id → manifest (with __sourceDir) for every marked folder on disk
  readonly property string home: Quickshell.env("HOME")

  System { id: system; host: root.host }
  Applications { id: applications; host: root.host }
  Converter { id: converter; host: root.host }
  Colors { id: colors; host: root.host }
  Emoji { id: emoji; host: root.host }
  Dictation { id: dictation; host: root.host }
  Clipboard { id: clipboard; host: root.host }
  Files { id: files; host: root.host }
  Hotkeys { id: hotkeys; host: root.host }
  AiWeb { id: aiWeb; host: root.host }
  Codex { id: codex; host: root.host }
  Extensions { id: extensions; host: root.host }
  SettingsProvider { id: settingsProvider; host: root.host }
  Providers.Timer { id: timerProvider; host: root.host }

  readonly property var bundled: [system, applications, converter, colors, emoji, clipboard, dictation, files, hotkeys, codex, aiWeb, extensions, settingsProvider, timerProvider]

  // Declared patterns are compiled here, once per rebuild, never per keystroke.
  // A pattern that does not compile is reported and skipped; the provider loads.
  function entry(key, provider, source, pluginId, name, issues) {
    var compiled = Patterns.compile(provider.patterns)
    for (var e = 0; e < compiled.errors.length; e++) issues.push({ pluginId: pluginId || key, message: "Pattern " + compiled.errors[e] })
    return { key: key, provider: provider, source: source, pluginId: pluginId, name: name, patterns: compiled.patterns }
  }

  function rebuild() {
    var out = [], issues = []
    for (var b = 0; b < bundled.length; b++)
      out.push(entry(bundled[b].provider.id, bundled[b].provider, "bundled", "", bundled[b].provider.name, issues))

    var ids = Object.keys(root.manifests).sort()
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i], service = root.services[id], manifest = root.manifests[id]
      // Disabled extensions remain manageable without evaluating their QML.
      var p = service ? service.instance.provider : { apiVersion: 1, id: id, name: manifest.name || id,
        description: manifest.description || "", settings: [], query: function(ctx) { return [] } }
      if (!p || typeof p !== "object") { issues.push({ pluginId: id, message: "Service.qml does not expose a provider object" }); continue }
      if (p.apiVersion !== 1) { issues.push({ pluginId: id, message: "Needs Keystroke provider API 1, plugin declares " + p.apiVersion }); continue }
      if (typeof p.query !== "function" || !p.name) { issues.push({ pluginId: id, message: "Provider must define name and query(ctx)" }); continue }
      out.push(entry(id, p, "community", id, manifest.name || id, issues))
    }
    root.entries = out
    root.problems = root.scanProblems.concat(root.loadProblems, issues)
  }

  // ------------------------------------------------------------ extensions
  // One scan when the registry is created and one per palette open, so a
  // folder that appeared out of band is picked up without a shell restart. A scan that finds
  // the same manifests changes nothing; a manifest that changed (an update)
  // recreates its service, a folder that disappeared destroys it.
  property var services: ({})      // plugin id → { instance, stamp }
  property var scanProblems: []
  property var loadProblems: []
  property string scanStamp: ""

  property bool scanAgain: false
  Process {
    id: scanner
    stdout: StdioCollector { onStreamFinished: root.applyScan(text) }
    onExited: if (root.scanAgain) { root.scanAgain = false; Qt.callLater(root.scan) }
  }
  function scan() {
    if (!root.host || !root.host.configKnown) return
    if (scanner.running) { root.scanAgain = true; return }
    scanner.command = ExtensionsModel.scanArgv(root.host.rootDir, ExtensionsModel.enabledIds(root.host.config))
    scanner.running = true
  }
  function applyScan(text) {
    var found = ExtensionsModel.parseScan(text), stamp = JSON.stringify(found)
    if (stamp === root.scanStamp) return
    root.scanStamp = stamp
    root.scanProblems = found.problems
    root.manifests = found.manifests
    root.sync()
  }
  function sync() {
    var next = ({}), issues = []
    for (var id in root.manifests) {
      var manifest = root.manifests[id], stamp = JSON.stringify(manifest), current = root.services[id]
      if (manifest.__enabled !== true || !root.host || !root.host.providerEnabled({ key: id, source: "community" })) continue
      if (current && current.stamp === stamp) { next[id] = current; continue }
      var instance = root.createService(id, manifest, issues)
      if (instance) next[id] = { instance: instance, stamp: stamp }
    }
    for (var gone in root.services) if (!next[gone] || next[gone].instance !== root.services[gone].instance) root.services[gone].instance.destroy()
    root.services = next
    root.loadProblems = issues
    root.rebuild()
  }
  function createService(id, manifest, issues) {
    var url = ExtensionsModel.serviceUrl(manifest)
    if (!url) { issues.push({ pluginId: id, message: "Needs kind \"service\" and entryPoints.service inside the plugin folder" }); return null }
    var component = Qt.createComponent(url, Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      issues.push({ pluginId: id, message: String(component.errorString() || "Service.qml failed to load").trim() })
      return null
    }
    var instance = component.createObject(root)
    if (!instance) { issues.push({ pluginId: id, message: "Service.qml could not be instantiated" }); return null }
    if ("omarchyPath" in instance) instance.omarchyPath = root.host ? root.host.omarchyPath : ""
    if ("shell" in instance) instance.shell = root.host ? root.host.shell : null
    if ("manifest" in instance) instance.manifest = ExtensionsModel.publicManifest(manifest)
    if ("host" in instance) instance.host = root.host
    return instance
  }
  // The shell injects Keystroke's `shell` after creating the palette; pass it on.
  Connections {
    target: root.host
    function onShellChanged() {
      for (var id in root.services) { var s = root.services[id].instance; if ("shell" in s) s.shell = root.host.shell }
    }
    function onConfigChanged() { root.sync(); root.scan() }
    function onConfigKnownChanged() { root.scan() }
  }

  onHostChanged: rebuild()
  Component.onCompleted: { rebuild(); scan() }
}
