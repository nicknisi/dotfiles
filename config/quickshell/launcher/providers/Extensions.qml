import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Settings.js" as Settings
import "../core/Extensions.js" as Extensions
import "../core/Patterns.js" as Patterns

// API 1 community providers managed by helpers/extensions.lua, one persistent
// job at a time. Discovery defaults to the shipped index. Installing code
// requires the host's confirmation before activate(ctx.confirmed) is called.
Item {
  id: root
  property var host: null
  readonly property string home: Quickshell.env("HOME")
  readonly property string rootDir: root.host ? root.host.rootDir : ""
  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/keystroke"

  property var indexEntries: []
  property var gitState: ({})          // id → { head, remoteHead, remote }
  property string checkedAt: ""
  property var job: null               // { kind, id, name, label, detail, url, queue, startedAt }
  property string fetching: ""
  property string fetchError: ""
  property double indexFetched: 0
  property double indexAttempted: 0
  property string attemptedSource: ""
  property bool autoChecked: false
  readonly property int freshMs: 60 * 60 * 1000

  readonly property var provider: ({
    apiVersion: 1,
    id: "extensions",
    name: "Extensions",
    icon: Extensions.ICON,
    color: "#8bceb4",
    description: "Install, update and manage community providers",
    settings: [
      { key: "autoCheck", type: "boolean", label: "Check for updates when the Extensions screen opens", "default": true,
        description: "Checks repository heads without changing checkouts, once per palette session" },
      { key: "indexUrl", type: "string", label: "Extension index URL", "default": Extensions.INDEX_URL,
        description: "Empty uses the shipped index; optionally supply an https or local file URL" }
    ],
    query: function(ctx) { return root.query(ctx) },
    activate: function(row, ctx) { return root.activate(row, ctx) },
    opened: function() { root.autoChecked = false }
  })

  // ------------------------------------------------------------- registry
  function registry() { return root.host ? root.host.registry : null }
  function rescan() { var reg = registry(); if (reg && typeof reg.scan === "function") reg.scan() }
  function installedList() {
    var reg = registry()
    if (!reg || !reg.manifests) return []
    var cfg = root.host ? root.host.config : null
    var list = Extensions.installed(reg.manifests, function(id) { return Settings.isEnabled(cfg, ["providers", id], false) }, root.gitState, reg.problems)
    // A loaded provider decorates its own rows: icon, image icon, accent and the query shapes it declares.
    for (var i = 0; i < list.length; i++) {
      var entry = root.host ? root.host.registryEntry(list[i].id) : null
      if (entry) Extensions.decorate(list[i], entry.provider, Patterns.examples(entry.patterns))
    }
    return list
  }
  function find(id) {
    var list = installedList()
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
    return null
  }
  Connections {
    target: root.host ? root.host.registry : null
    function onManifestsChanged() { if (root.host) root.host.requery() }
    function onProblemsChanged() { if (root.host) root.host.requery() }
  }

  // ---------------------------------------------------------------- caches
  FileView {
    id: shippedIndex
    printErrors: false
    path: root.rootDir ? root.rootDir + "/extensions/index.json" : ""
    onLoaded: { if (!root.settings().indexUrl) { root.indexEntries = Extensions.parseIndex(text()); if (root.host) root.host.requery() } }
    onLoadFailed: {}
  }
  FileView { id: indexCache; printErrors: false; atomicWrites: true; path: root.cacheDir + "/extensions-index.json"; onLoaded: root.readCache(); onLoadFailed: {} }
  property string indexSource: ""
  function readCache() {
    var doc
    try { doc = JSON.parse(indexCache.text()) } catch (e) { return }
    if (!doc || !doc.url || doc.url !== String(root.settings().indexUrl || "")) return
    root.indexEntries = Extensions.parseIndex(doc.body || "")
    root.indexSource = doc.url
    root.indexFetched = Number(doc.fetchedAt || 0)
    root.attemptedSource = doc.url
    if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
  }

  Process {
    id: fetcher
    property string url: ""
    stdout: StdioCollector { id: fetchedIndex }
    onExited: function(code) {
      root.fetching = ""
      if (code !== 0) root.fetchError = "Could not fetch the index (curl exit " + code + ")"
      else {
        var body = fetchedIndex.text, doc
        try { doc = JSON.parse(body) } catch (e) { doc = null }
        if (!doc || doc.version !== 1 || !Array.isArray(doc.extensions)) root.fetchError = "Index unreadable: " + fetcher.url
        else if (fetcher.url === String(root.settings().indexUrl || "")) {
          root.indexEntries = Extensions.parseIndex(body)
          root.indexSource = fetcher.url
          root.indexFetched = Date.now()
          indexCache.setText(JSON.stringify({ fetchedAt: root.indexFetched, url: fetcher.url, body: body }))
        }
      }
      if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
    }
  }
  function refresh() {
    if (fetcher.running) return
    var url = String(root.settings().indexUrl || "")
    root.indexAttempted = Date.now()
    root.attemptedSource = url
    if (root.indexSource !== url) root.indexEntries = []
    root.fetchError = ""
    if (!url) {
      root.indexEntries = Extensions.parseIndex(shippedIndex.text())
      root.indexSource = ""
      root.indexFetched = Date.now()
      shippedIndex.reload()
      return
    }
    if (!Extensions.gitUrl(url) || (url.indexOf("https://") !== 0 && url.indexOf("file:///") !== 0)) { root.fetchError = "Index URL must be https or an absolute file URL"; return }
    root.fetching = "index"
    fetcher.url = url
    fetcher.command = Extensions.fetchArgv(url)
    fetcher.running = true
  }
  function ensureFresh() {
    if (fetcher.running) return
    if (root.attemptedSource !== String(root.settings().indexUrl || "") || Date.now() - Math.max(root.indexFetched, root.indexAttempted) > root.freshMs) root.refresh()
  }
  function settings() {
    var entry = root.host ? root.host.registryEntry("extensions") : null
    return entry ? root.host.settingsFor(entry) : Settings.values(null, [], root.provider.settings)
  }

  // ------------------------------------------------------------------ jobs
  // One job at a time, run detached (see Extensions.jobArgv). State survives
  // palette recreation and is polled while the helper runs. A fresh instance
  // picks up a running job or a result nobody has read yet. A job ends when its result is
  // read; job.json disappearing on its own (the wrapper died before writing
  // a result) ends it only once result.json is confirmed absent too, so a
  // finished job is never mistaken for an idle provider before its result
  // has been acted on. Each result is finished once per instance.
  readonly property string jobDir: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/keystroke/extensions"
                                   : (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/keystroke/extensions-jobs"
  property bool jobGone: false
  property double consumed: 0      // startedAt of the last result this instance finished
  FileView { id: jobFile; printErrors: false; path: root.jobDir + "/job.json"; onLoaded: root.readJob(); onLoadFailed: { root.jobGone = true; resultFile.reload() } }
  FileView { id: resultFile; printErrors: false; path: root.jobDir + "/result.json"; onLoaded: root.readResult(); onLoadFailed: { if (root.jobGone) root.job = null } }
  Timer { id: poll; interval: 400; repeat: true; running: root.job !== null; onTriggered: { resultFile.reload(); jobFile.reload() } }
  function readJob() {
    var j
    try { j = JSON.parse(jobFile.text()) } catch (e) { return }
    if (j && typeof j === "object" && j.kind && j.startedAt > root.consumed) { root.job = j; root.jobGone = false }
  }
  function readResult() {
    var r = Extensions.parseResult(resultFile.text())
    if (!r || r.job.startedAt <= root.consumed) return
    root.consumed = r.job.startedAt
    if (root.job && root.job.startedAt === r.job.startedAt) root.job = null
    root.finish(r.job, r.code, r.output)
    Quickshell.execDetached(Extensions.ackArgv(root.rootDir, r.job.startedAt))
  }
  function finish(j, code, output) {
    var tail = output.trim().split("\n").filter(Boolean).slice(-1)[0] || ""
    if (j.kind === "check" && code === 0) {
      var parsed = Extensions.parseCheck(output)
      var next = ({})
      for (var k in root.gitState) next[k] = root.gitState[k]
      for (var id in parsed) next[id] = parsed[id]
      root.gitState = next
      root.checkedAt = Qt.formatTime(new Date(), "HH:mm")
      var updates = 0
      for (var u in next) if (next[u].head && next[u].remoteHead && next[u].head !== next[u].remoteHead) updates++
      if (root.host && !j.quiet) root.host.statusMessage = updates ? updates + " update" + (updates === 1 ? "" : "s") + " available" : "Extensions are up to date"
    } else if (code === 0) {
      if (j.kind === "install") root.afterInstall(Extensions.parseAdded(output), j.enable === true)
      if (j.kind === "update") {
        var g = ({}); for (var gk in root.gitState) if (gk !== j.id) g[gk] = root.gitState[gk]; root.gitState = g
        root.rescan()
        if (j.queue && j.queue.length) root.updateQueue(j.queue)
        else root.check([j.id], true)
      }
      if (j.kind === "remove") {
        var remaining = ({}); for (var rk in root.gitState) if (rk !== j.id) remaining[rk] = root.gitState[rk]; root.gitState = remaining
        root.rescan(); if (root.host && root.host.scope === Extensions.KEY + "/" + j.id) root.host.goBack()
      }
      if (root.host) root.host.statusMessage = j.done || tail
    } else if (root.host) {
      root.host.errorMessage = (j.label + ": " + (tail || "exit " + code)).slice(0, 300)
    }
    if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
  }
  function run(job, argv) {
    if (root.job) { if (root.host) root.host.errorMessage = "Another extension job is still running"; return false }
    job.startedAt = Math.max(Date.now(), root.consumed + 1)
    root.job = job
    try { Quickshell.execDetached(Extensions.jobArgv(root.jobDir, job, root.rootDir, argv)) }
    catch (e) { root.job = null; if (root.host) root.host.errorMessage = String(e); return false }
    if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
    return true
  }
  // quiet: a check that follows an install or update refreshes the git state
  // without replacing the status line that reports what just happened.
  function check(ids, quiet) {
    if (!ids.length) { root.checkedAt = Qt.formatTime(new Date(), "HH:mm"); return }
    root.run({ kind: "check", quiet: !!quiet, id: ids.length === 1 ? ids[0] : "", label: "Checking for updates", detail: ids.length + " extension" + (ids.length === 1 ? "" : "s") },
             Extensions.checkArgv(root.rootDir, ids))
  }
  function gitManaged() {
    var reg = registry(), ids = []
    if (!reg || !reg.manifests) return ids
    for (var id in reg.manifests) ids.push(id)
    return ids
  }
  // Read once at creation and once more shortly after: a job launched a
  // moment before this instance existed may not have written job.json yet.
  Component.onCompleted: { jobFile.reload(); resultFile.reload() }
  Timer { interval: 700; running: true; onTriggered: { jobFile.reload(); resultFile.reload() } }

  function activate(row, ctx) {
    var effect = ctx.alternate && row.altAction ? row.altAction : row.action
    if (!effect || effect.type !== "ext") return effect
    // Older upstream hosts called activate BEFORE asking for confirmation.
    // Fail closed until the native host defers activation and marks it confirmed.
    if ((effect.op === "install" || effect.op === "remove") && ctx.confirmed !== true) {
      if (root.host) root.host.errorMessage = "Confirm this extension operation before activation"
      return { type: "noop" }
    }
    var name = effect.name || effect.id
    switch (effect.op) {
    case "install":
      root.run({ kind: "install", id: effect.id, name: name, label: "Installing " + name, detail: effect.url, done: "Installed " + name, url: effect.url, enable: true },
               Extensions.installArgv(root.rootDir, effect.url, effect.id))
      return { type: "noop" }
    case "update":
      root.run({ kind: "update", id: effect.id, name: name, label: "Updating " + name, detail: effect.id, done: Extensions.updatedText(name) }, Extensions.updateArgv(root.rootDir, effect.id))
      return { type: "noop" }
    case "update-all": {
      var ids = [], list = installedList()
      for (var i = 0; i < list.length; i++) if (list[i].updateAvailable) ids.push(list[i].id)
      root.updateQueue(ids)
      return { type: "noop" }
    }
    case "remove":
      // Revoke authorization before deleting the checkout. A later copy with
      // the same ID must not inherit permission to execute its QML.
      root.host.saveConfig(Settings.withValue(root.host.config, ["providers", effect.id], "enabled", false, { key: "enabled", type: "boolean" }), function() {
        root.run({ kind: "remove", id: effect.id, name: name, label: "Removing " + name, detail: effect.id, done: "Removed " + name }, Extensions.removeArgv(root.rootDir, effect.id))
      })
      return { type: "noop" }
    case "check":
      root.check(effect.id ? [effect.id] : root.gitManaged())
      return { type: "noop" }
    case "refresh":
      root.indexFetched = 0
      root.refresh()
      return { type: "noop" }
    }
    return { type: "noop" }
  }

  // Sequential updates: one native helper job per extension; the rest of
  // the queue rides in the job so a recreated instance can continue it.
  function updateQueue(ids) {
    if (!ids.length) return
    var id = ids[0], rest = ids.slice(1), e = find(id)
    root.run({ kind: "update", id: id, name: e ? e.name : id, label: "Updating " + (e ? e.name : id), detail: rest.length ? rest.length + " more queued" : id,
               done: Extensions.updatedText(e ? e.name : id), queue: rest }, Extensions.updateArgv(root.rootDir, id))
  }

  // Only a confirmed installation decision enables code. CLI installs and
  // hand-copied folders stay off. A failed config write never authorizes loading.
  function afterInstall(id, enable) {
    if (!Extensions.validId(id)) { if (root.host) root.host.errorMessage = "Install did not report a validated extension ID"; return }
    if (enable && root.host) {
      try { root.host.saveConfig(Settings.withValue(root.host.config, ["providers", id], "enabled", true, { key: "enabled", type: "boolean" })) }
      catch (e) { root.host.errorMessage = "Installed but could not enable: " + String(e) }
    }
    root.rescan()
    root.check([id], true)
  }

  // ----------------------------------------------------------------- query
  function query(ctx) {
    var id = Extensions.scopeId(ctx.scope)
    if (ctx.scope && id === null) return []
    if (!ctx.scope) {
      if (!ctx.query) return [Extensions.navRow(8)]
      var s = Match.match(ctx.query, "Extensions", "plugins store marketplace community install", "", "extensions plugins store marketplace community providers install update")
      return s ? [Extensions.navRow(s)] : []
    }
    root.ensureFresh()
    if (root.job || root.fetching) ctx.pending()
    var state = { installed: installedList(), discover: Extensions.discover(root.indexEntries),
                  job: root.job, fetching: !!root.fetching, checked: root.checkedAt, error: root.fetchError }
    if (id === "") {
      if (ctx.settings.autoCheck && !root.autoChecked && !root.job) { root.autoChecked = true; root.check(root.gitManaged()) }
      return Extensions.screenRows(ctx.query, state)
    }
    var e = find(id)
    if (!e) return [{ id: "gone", title: "Extension not installed", subtitle: id, icon: Extensions.ICON, verb: "", tier: "item", score: 1, disabled: true, action: { type: "noop" } }]
    return Extensions.detailRows(ctx.query, e, state)
  }
}
