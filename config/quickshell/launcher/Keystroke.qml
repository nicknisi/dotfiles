pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.Commons
import qs.Ui
import "ui"
import "providers" as Providers
import "voice"
import "core"
import "core/Match.js" as Match
import "core/Frecency.js" as Frecency
import "core/Files.js" as FileSearch
import "core/Settings.js" as Settings
import "core/VoiceBindings.js" as VoiceBindings
import "core/UserHotkeys.js" as UserHotkeys
import "core/Intent.js" as Intent
import "core/Patterns.js" as Patterns
import "core/SmartMatch.js" as SmartMatch
import "core/Motion.js" as Motion
import "core/Glyphs.js" as Glyphs
import "matching" as Matching

// Native shell host for the MIT-licensed Keystroke command palette.
Item {
  id: root

  // Retained for the community provider context, not an installation dependency.
  property string omarchyPath: ""
  readonly property string rootDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")
  property var targetScreen: null
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  readonly property var appLibrary: applicationLibrary.library
  ApplicationLibrary { id: applicationLibrary; hostShell: root.shell; omarchyPath: root.omarchyPath }
  readonly property string home: Quickshell.env("HOME")
  function xdgPath(name, fallback) {
    var path = Quickshell.env(name)
    return path && path.charAt(0) === "/" ? path.replace(/\/+$/, "") : fallback
  }
  readonly property string configDir: xdgPath("XDG_CONFIG_HOME", home + "/.config")
  readonly property string stateDir: xdgPath("XDG_STATE_HOME", home + "/.local/state") + "/keystroke"
  readonly property string configPath: configDir + "/quickshell-launcher.json"
  readonly property string usagePath: stateDir + "/usage.json"

  // ------------------------------------------------------------ lifecycle
  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) payload = ({})
    if (payload.mode === "select" || payload.mode === "input") root.openDmenu(payload)
    else root.openRoute(payload.route || payload.initialMenu || payload.menu || "root", payload)
  }
  // Toggle uses close() for second-tap voice. Explicit IPC close, Esc and
  // outside clicks use cancel() and never start recording.
  function close() {
    if (root.opened && !root.dmenuActive && root.voiceEnabled && !root.confirmPending) {
      if (voice.phase === "starting" || voice.phase === "listening") { root.voiceStop(); return }
      if (voice.phase === "transcribing") return
      if (root.voiceSettings.secondTap === "voice" && root.voiceBegin("tap")) return
    }
    root.cancel()
  }
  function refresh() { providerRegistry.bundled[0].reload(); root.requery(); return "ok" }
  function ping() { return "ok" }
  // Hyprland long-press bind on the hotkey: the key is still down 250 ms
  // after the palette opened, so this is a hold, not a tap.
  function voiceHold(arg) {
    if (!root.opened || root.dmenuActive) return "ignored"
    if (voice.active) { root.voiceTrigger = "hold"; return "listening" }
    return root.voiceBegin("hold") ? "listening" : "ignored"
  }
  // Hyprland release bind on the hotkey (fires while the modifier is still
  // held; the modifier's own release is caught in the search field).
  function voiceRelease(arg) {
    if (!voice.active || root.voiceTrigger !== "hold") return "ignored"
    root.voiceStop()
    return "stopping"
  }

  // Optional provider views share the palette window, focus and voice lifecycle.
  property string activeProviderKey: ""
  property string providerViewRawQuery: ""
  readonly property bool providerViewActive: activeProviderKey.length > 0
  function focusInput() {
    if (!root.opened || root.confirmPending) return
    if (root.providerViewActive && providerView.item && typeof providerView.item.focusInput === "function") providerView.item.focusInput()
    else search.forceActiveFocus()
  }
  function closeProviderView() {
    if (providerView.item && typeof providerView.item.dismiss === "function") providerView.item.dismiss()
    root.activeProviderKey = ""
    root.providerViewRawQuery = ""
    providerView.sourceComponent = null
  }
  function showProviderView(key) {
    var entry = root.registryEntry(key)
    if (!entry || !root.providerEnabled(entry) || !entry.provider.view) { root.errorMessage = "Provider view is unavailable"; return }
    matchingSession.cancelRequest()
    root.providerViewRawQuery = root.voiceRawText
    root.activeProviderKey = key
    providerView.sourceComponent = entry.provider.view
    root.slideLevel(1)
  }
  // A view whose provider was removed, unloaded or turned off while it was
  // showing (a community plugin disabled from the CLI, say) must not linger
  // over the palette with a destroyed context behind it.
  function dropOrphanedView() {
    if (!root.providerViewActive) return
    var entry = root.registryEntry(root.activeProviderKey)
    if (entry && root.providerEnabled(entry)) return
    root.closeProviderView()
    if (root.opened) { root.runQuery(); search.forceActiveFocus() }
  }
  Connections {
    target: providerRegistry
    function onEntriesChanged() { root.invalidateCatalog(); root.dropOrphanedView() }
  }
  onConfigChanged: { root.invalidateCatalog(); root.dropOrphanedView() }

  // -------------------------------------------------------------- settings
  property var config: Settings.empty()
  property string configError: ""
  property bool configKnown: false
  readonly property var paletteSchema: [
    { key: "density", type: "enum", label: "Layout density", "default": "compact", options: ["compact", "comfortable"], description: "Compact uses a narrower window and shorter rows" },
    { key: "showPreview", type: "boolean", label: "Show result previews", "default": true },
    { key: "animations", type: "enum", label: "Animations", "default": "snappy", options: ["off", "snappy", "fluid"],
      description: "Off shows every change at once; Snappy ties changes together over a couple of frames; Fluid eases them" },
    { key: "windowTransition", type: "enum", label: "Window transition", "default": "instant", options: ["instant", "fade", "slide"],
      optionLabels: { instant: "Instant", fade: "Fade", slide: "Slide up" },
      description: "Instant maps and unmaps the palette at once; Fade and Slide up follow the animation tier" }
  ]
  property var paletteSettings: Settings.values(config, ["palette"], paletteSchema)
  readonly property var matchingSchema: SmartMatch.SCHEMA
  readonly property var matchingSettings: Settings.values(config, ["matching"], matchingSchema)
  readonly property string matchingStamp: matchingSession.status + "|" + matchingSession.error
  function matchingModel() { return { schemas: root.matchingSchema, values: root.matchingSettings, status: matchingSession.status, error: matchingSession.error } }
  Matching.Session {
    id: matchingSession
    enabled: root.configKnown && root.matchingSettings.mode !== "off"
    model: root.matchingSettings.model
    onChanged: if (root.opened && !root.confirmPending) root.requery({ catalog: false })
  }
  property var intentDescriptions: ({})
  property var intentDescriptionKeys: ({})
  FileView {
    path: Qt.resolvedUrl("matching/descriptions.json").toString().replace("file://", "")
    printErrors: false
    onLoaded: { try { root.intentDescriptions = JSON.parse(text()); root.requery() } catch (_) { } }
  }
  FileView {
    path: Qt.resolvedUrl("matching/description-keys.json").toString().replace("file://", "")
    printErrors: false
    onLoaded: { try { root.intentDescriptionKeys = JSON.parse(text()); root.requery() } catch (_) { } }
  }
  // The fingerprint hash is memoized per row identity: hashing costs about
  // 25 µs per row in the QML engine and the catalog is rebuilt as a whole.
  property var describeCache: ({})
  function describe(row) {
    var prefix = row.providerKey === "system" ? "menu:" : row.providerKey === "applications" ? "app:" : row.providerKey === "hotkeys" ? "hotkey:" : ""
    var id = prefix + row.id
    if (prefix === "app:" && !root.intentDescriptionKeys[id]) id += ".desktop"
    var key = root.intentDescriptionKeys[id]
    if (!key || key.title !== row.title) return row
    var source = String(row.descriptionKey || ""), hit = root.describeCache[row.uid]
    if (!hit || hit.source !== source) { hit = { source: source, hash: Qt.md5(source) }; root.describeCache[row.uid] = hit }
    if (key.key === hit.hash) row.intentDescription = root.intentDescriptions[id] || ""
    return row
  }
  function paletteValues() { return root.paletteSettings }
  function settingsFor(entry) { return Settings.values(root.config, ["providers", entry.key], entry.provider.settings || []) }
  function providerEnabled(entry) { return Settings.isEnabled(root.config, ["providers", entry.key], entry.source !== "community") }
  function registryEntry(key) {
    for (var i = 0; i < providerRegistry.entries.length; i++) if (providerRegistry.entries[i].key === key) return providerRegistry.entries[i]
    return null
  }
  function applyConfigText(text) {
    var parsed = Settings.parse(text)
    root.configError = parsed.error
    if (parsed.config) root.config = parsed.config
    root.paletteSettings = Settings.values(root.config, ["palette"], root.paletteSchema)
  }
  function saveConfig(next, afterSaved) {
    if (root.configError) throw new Error(root.configError)
    if ((root.writing && root.writing.file === configFile) || root.writeQueue.some(function(job) { return job.file === configFile }))
      throw new Error("Settings are still saving. Try again.")
    root.writeFile(configFile, Settings.serialize(next), root.configDir, function() {
      root.applyConfigText(Settings.serialize(next))
      root.statusMessage = "Saved"
      root.requery()
      if (afterSaved) afterSaved()
    })
  }

  // Serialize directory preparation and atomic FileView writes. No path or
  // document is interpolated into shell source, and mkdir finishes first.
  property var writeQueue: []
  property var writing: null
  function writeFile(file, text, directory, after) {
    root.writeQueue = root.writeQueue.concat([{ file: file, text: text, directory: directory, after: after }])
    root.nextWrite()
  }
  function nextWrite() {
    if (root.writing || !root.writeQueue.length) return
    root.writing = root.writeQueue[0]
    root.writeQueue = root.writeQueue.slice(1)
    makeDirectory.command = ["mkdir", "-p", "--", root.writing.directory]
    makeDirectory.running = true
  }
  function written(ok) {
    var job = root.writing
    root.writing = null
    if (!ok) root.errorMessage = "Could not save " + (job ? job.file.path : "launcher data")
    else if (job && job.after) job.after()
    Qt.callLater(root.nextWrite)
  }
  Process {
    id: makeDirectory
    onExited: function(code) {
      if (code !== 0) root.written(false)
      else if (root.writing) root.writing.file.setText(root.writing.text)
    }
  }
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: { root.applyConfigText(text()); root.configKnown = true }
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) root.applyConfigText("")
      else root.configError = "Could not read " + root.configPath
      root.configKnown = true
    }
    onSaved: root.written(true)
    onSaveFailed: root.written(false)
    onFileChanged: reload()
  }

  // ----------------------------------------------------------------- voice
  // Dictation through an optional local voxtype daemon. Two ways in: hold the
  // palette hotkey (Hyprland long-press bind → voiceHold; its release bind or
  // the modifier's own release → stop), or tap the hotkey again while the
  // palette is open (a further tap stops). Enter finishes recording; a fresh
  // Enter after transcription runs the visible selection. Replies never execute.
  VoiceSession {
    id: voxtypeVoice
    host: root
    onPartial: function(text) { root.voiceLive(text) }
    onTranscribed: function(text) { root.voiceTranscribed(text) }
    onNothingHeard: { root.dictationPending = ""; if (root.opened) root.statusMessage = "Nothing heard" }
    onFailed: function(message) { root.dictationPending = ""; if (root.opened) root.errorMessage = message }
  }
  readonly property var voice: voxtypeVoice
  readonly property var voiceSchema: [
    { key: "enabled", type: "boolean", label: "Voice command integration", "default": true,
      description: "Hold the palette hotkey, or tap it again while the palette is open, to dictate the query" },
    { key: "secondTap", type: "enum", label: "Second tap of the hotkey", "default": "voice", options: ["voice", "close"],
      description: "Voice starts dictation and a third tap stops it (Esc closes); Close is the stock toggle" },
    { key: "keys", type: "string", label: "Hotkeys to hold", "default": "SUPER + SPACE",
      description: "Hyprland combos for the long-press bindings, comma-separated, e.g. SUPER + SPACE, SUPER + SHIFT + code:201" }
  ]
  property var voiceSettings: Settings.values(root.config, ["voice"], root.voiceSchema)
  readonly property bool voiceEnabled: voice.detected && voiceSettings.enabled === true
  property string voiceTrigger: "tap"      // hold | tap
  property bool voiceDiscard: false        // the user typed while transcribing: the transcript loses
  readonly property string bindingsPath: home + "/.config/hypr/launcher-voice.lua"
  property string bindingsText: ""
  property bool bindingsKnown: false       // read, or confirmed absent: safe to rewrite
  FileView {
    id: bindingsFile
    path: root.bindingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: { root.bindingsText = text(); root.bindingsKnown = true }
    onLoadFailed: function(error) { root.bindingsText = ""; root.bindingsKnown = error === FileViewError.FileNotFound }
    onSaved: root.written(true)
    onSaveFailed: root.written(false)
    onFileChanged: reload()
  }
  readonly property string voiceBindingsStatus: root.bindingsKnown ? VoiceBindings.status(root.bindingsText, root.voiceSettings.keys) : "missing"
  readonly property string voiceStamp: [voice.detected, voice.version, voice.daemonState, root.voiceBindingsStatus, root.bindingsKnown].join("|")
  function voiceModel() {
    return { schemas: root.voiceSchema, values: root.voiceSettings, detected: voice.detected, version: voice.version, daemonState: voice.daemonState,
             bindings: root.voiceBindingsStatus, bindingsPath: "~/.config/hypr/launcher-voice.lua" }
  }
  // --------------------------------------------------------------- hotkeys
  // Ctrl+B on a result records a chord and writes a native bind into the
  // dedicated ~/.config/hypr/launcher-hotkeys.lua (core/UserHotkeys.js). The
  // file is the store: its lines are parsed back to label rows, show a bound
  // row's chord and detect conflicts. Each bind runs `qs ipc call launcher run
  // <provider>/<id>`, which activates the row exactly as Enter would.
  readonly property string hotkeysPath: home + "/.config/hypr/launcher-hotkeys.lua"
  property string hotkeysText: ""
  property bool hotkeysKnown: false        // read, or confirmed absent: safe to rewrite
  property var hotkeys: UserHotkeys.parse("")
  readonly property var hotkeysByRoute: UserHotkeys.byRoute(root.hotkeys.entries)
  FileView {
    id: hotkeysFile
    path: root.hotkeysPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: { root.hotkeysText = text(); root.hotkeysKnown = true; root.hotkeys = UserHotkeys.parse(root.hotkeysText); root.requery() }
    onLoadFailed: function(error) { root.hotkeysText = ""; root.hotkeysKnown = error === FileViewError.FileNotFound; root.hotkeys = UserHotkeys.parse("") }
    onSaved: root.written(true)
    onSaveFailed: root.written(false)
    onFileChanged: reload()
  }
  function hotkeysProvider() {
    for (var i = 0; i < providerRegistry.bundled.length; i++) if (providerRegistry.bundled[i].provider.id === "hotkeys") return providerRegistry.bundled[i]
    return null
  }
  function liveBinds() { var p = root.hotkeysProvider(); return p ? p.binds : [] }

  // Rows that can be bound: stable ids a provider can hand back from its
  // catalog. Answers, picker rows, files and clipboard entries have none.
  readonly property var unbindableActions: ({ noop: true, setting: true, edit: true, close: true, "matching-retry": true, "voice-bindings": true, "dictation-copy": true, "unbind-hotkey": true })
  function bindable(row) {
    if (!row || !row.uid || row.disabled || row.tier !== "item" || root.dmenuActive || row.providerKey === "dmenu") return false
    if (!row.action || root.unbindableActions[row.action.type] || !UserHotkeys.validRoute(row.uid)) return false
    var entry = root.registryEntry(row.providerKey)
    if (!entry || !root.providerEnabled(entry)) return false
    return typeof entry.provider.catalog === "function" || (entry.source === "bundled" && row.action.type === "navigate")
  }
  // The row a route names, from its provider's catalog, or null.
  function resolveRoute(route) {
    var text = String(route || "")
    if (!UserHotkeys.validRoute(text)) return null
    var slash = text.indexOf("/"), entry = root.registryEntry(text.slice(0, slash)), id = text.slice(slash + 1)
    if (!entry || !root.providerEnabled(entry)) return null
    var ctx = { query: "", rawQuery: "", scope: "", sub: "", generation: root.generation, settings: root.settingsFor(entry),
                patterns: Patterns.evaluate(entry.patterns, ""), pending: function() {}, host: root, shell: root.shell, appLibrary: root.appLibrary, omarchyPath: root.omarchyPath }
    var rows = []
    try {
      if (typeof entry.provider.catalog === "function") rows = entry.provider.catalog(ctx) || []
      else if (entry.source === "bundled") rows = (entry.provider.query(ctx) || []).filter(function(c) { return c.action && c.action.type === "navigate" })
    } catch (e) { return null }
    var row = rows.find(function(candidate) { return candidate && String(candidate.id) === id })
    return row ? root.normalize(row, entry, "", 0) : null
  }
  // `qs ipc call launcher run <provider>/<id>`: the Hyprland side of a palette
  // hotkey. A row that confirms or opens a screen needs the palette; anything
  // else runs without showing it. A provider still loading gets one retry.
  property string pendingRun: ""
  Timer {
    id: runRetry; interval: 600
    onTriggered: {
      var route = root.pendingRun
      root.pendingRun = ""
      if (!root.runRoute(route, false)) Quickshell.execDetached(["notify-send", "--", "Launcher", "Nothing to run for " + route])
    }
  }
  function run(route) { return root.runRoute(String(route || ""), true) }
  function runRoute(route, retry) {
    var row = root.resolveRoute(route)
    if (!row || row.disabled) {
      if (!retry) return false
      var slash = route.indexOf("/"), entry = slash > 0 ? root.registryEntry(route.slice(0, slash)) : null
      if (!entry || !root.providerEnabled(entry)) return false
      if (typeof entry.provider.catalog !== "function" && entry.source !== "bundled") return false   // nothing to list later either
      if (typeof entry.provider.opened === "function") { try { entry.provider.opened() } catch (e) { } }
      root.pendingRun = route
      runRetry.restart()
      return "pending"
    }
    var type = row.action ? row.action.type : ""
    var needsPalette = !!row.confirm || type === "navigate" || type === "provider-view" || type === "system-view" || type === "dictate"
    if (needsPalette && !root.opened) root.openRoute("root", {})
    root.activateRow(row, false, true)
    return "ok"
  }

  // Recording a chord. Hyprland sits in an empty submap meanwhile, so a chord
  // that is already bound reaches the palette (and is reported as taken)
  // instead of firing. Escape leaves the submap even if the palette is gone.
  property var captureRow: null
  property string captureChord: ""
  property string capturePartial: ""
  property var captureCheck: ({ state: "invalid", message: "Press a key combination" })
  readonly property bool capturing: captureRow !== null
  readonly property bool hotkeyHint: !root.capturing && !root.clipboardChoice && root.bindable(root.current)
  function beginCapture() {
    var row = root.current
    if (root.capturing || root.confirmPending || voice.active) return false
    if (!root.bindable(row)) { root.errorMessage = "This result can't be given a hotkey"; return false }
    if (!root.hotkeysKnown) { root.errorMessage = "Could not read " + root.hotkeysPath; return false }
    if (!root.resolveRoute(row.uid)) { root.errorMessage = "This result can't be given a hotkey"; return false }
    var hotkeys = root.hotkeysProvider()
    if (hotkeys) hotkeys.refresh(true)
    root.errorMessage = ""
    root.statusMessage = ""
    root.captureChord = ""
    root.capturePartial = ""
    root.captureCheck = { state: "invalid", message: "Press a key combination" }
    root.captureRow = row
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"" + UserHotkeys.SUBMAP + "\")"])
    return true
  }
  function endCapture() {
    if (!root.capturing) return
    root.captureRow = null
    root.captureChord = ""
    root.capturePartial = ""
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])
  }
  function captureKey(event) {
    if (event.isAutoRepeat) return
    if (event.key === Qt.Key_Escape) { root.endCapture(); return }
    var result = UserHotkeys.chord(event.key, event.modifiers, event.text)
    if (result.partial !== undefined) { root.capturePartial = result.partial; return }
    var bare = !(event.modifiers & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier))
    if (bare && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { root.commitCapture(); return }
    if (bare && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)) {
      if (root.captureChord) { root.captureChord = ""; root.captureCheck = { state: "invalid", message: "Press a key combination" } }
      else root.removeCaptureBinding()
      return
    }
    root.capturePartial = ""
    root.captureChord = result.combo || ""
    root.captureCheck = result.error ? { state: "invalid", message: result.error }
                      : UserHotkeys.check(result.combo, root.captureRow.uid, root.hotkeys.entries, root.liveBinds())
  }
  readonly property var captureCurrent: root.captureRow ? root.hotkeysByRoute[root.captureRow.uid] || null : null
  readonly property bool captureReady: root.captureChord !== "" && (captureCheck.state === "available" || captureCheck.state === "replace" || captureCheck.state === "move")
  function commitCapture() {
    if (!root.captureReady) return
    var row = root.captureRow, chord = root.captureChord, check = root.captureCheck
    var entries = UserHotkeys.withBinding(root.hotkeys.entries, chord, row.uid, row.title)
    root.endCapture()
    root.confirmPending = {
      message: "Bind " + UserHotkeys.display(chord) + " to " + row.title + "?" + (check.state === "available" ? "" : " " + check.message + ".")
               + " This writes " + root.hotkeysPath.replace(root.home, "~") + " and reloads Hyprland.",
      confirmText: "Bind",
      run: function() { root.saveHotkeys(entries, UserHotkeys.display(chord) + " → " + row.title) }
    }
  }
  function removeCaptureBinding() {
    var current = root.captureCurrent
    if (!current) return
    root.endCapture()
    root.removeHotkey(current.route, current.label, current.combo)
  }
  function removeHotkey(route, label, combo) {
    var current = UserHotkeys.forRoute(root.hotkeys.entries, String(route || ""))
    if (!current) { root.errorMessage = "No palette hotkey for " + (label || route); return }
    var entries = UserHotkeys.withoutRoute(root.hotkeys.entries, current.route)
    root.confirmPending = {
      message: "Remove " + UserHotkeys.display(current.combo) + " from " + current.label + "? This rewrites " + root.hotkeysPath.replace(root.home, "~") + " and reloads Hyprland.",
      confirmText: "Remove",
      run: function() { root.saveHotkeys(entries, "Removed " + UserHotkeys.display(current.combo)) }
    }
  }
  // Write, reload, then ask Hyprland for config errors: a rejected config
  // puts the previous text back and reloads again.
  property string hotkeysRollback: ""
  property string hotkeysStatus: ""
  property bool hotkeysReverting: false
  property bool hotkeysReloadAgain: false
  function saveHotkeys(entries, status) {
    if (!root.hotkeysKnown) { root.errorMessage = "Could not read " + root.hotkeysPath; return }
    var previous = root.hotkeysText
    var next = UserHotkeys.apply(previous, entries, root.hotkeys.foreign)
    root.writeFile(hotkeysFile, next, root.home + "/.config/hypr", function() {
      root.hotkeysText = next
      root.hotkeys = UserHotkeys.parse(next)
      root.hotkeysRollback = previous
      root.hotkeysStatus = status
      root.hotkeysReverting = false
      root.statusMessage = status + " · reloading Hyprland…"
      root.requery()
      root.reloadHyprland()
    })
  }
  // A save landing while the previous reload runs queues one more reload.
  function reloadHyprland() {
    if (hyprReload.running) root.hotkeysReloadAgain = true
    else hyprReload.running = true
  }
  function hotkeysApplied() {
    var hotkeys = root.hotkeysProvider()
    if (hotkeys) hotkeys.refresh(true)
    root.requery()
  }
  function revertHotkeys(report) {
    var previous = root.hotkeysRollback
    root.errorMessage = "Hyprland rejected the config; hotkey reverted: " + report.split("\n")[0]
    root.writeFile(hotkeysFile, previous, root.home + "/.config/hypr", function() {
      root.hotkeysText = previous
      root.hotkeys = UserHotkeys.parse(previous)
      root.hotkeysReverting = true
      root.requery()
      root.reloadHyprland()
    })
  }
  Process {
    id: hyprReload
    command: ["hyprctl", "reload"]
    onExited: function(code) {
      if (root.hotkeysReloadAgain) { root.hotkeysReloadAgain = false; hyprReload.running = true; return }
      if (root.hotkeysReverting) { root.hotkeysReverting = false; root.hotkeysApplied(); return }
      if (code !== 0) { root.statusMessage = root.hotkeysStatus + " · saved, reload Hyprland to apply"; root.hotkeysApplied(); return }
      hyprErrors.running = true
    }
  }
  Process {
    id: hyprErrors
    command: ["hyprctl", "configerrors"]
    stdout: StdioCollector {
      onStreamFinished: {
        var report = String(text || "").trim()
        if (report) { root.revertHotkeys(report); return }
        root.statusMessage = root.hotkeysStatus
        root.hotkeysApplied()
      }
    }
  }

  readonly property bool dictationMode: !root.dmenuActive && root.scope === "dictation"
  property string dictationPending: ""   // explicit Enter intent: copy | paste
  ClipboardTransfer {
    id: clipboardTransfer
    onCopied: root.cancel(true)
    onFailed: function(message) {
      if (root.opened) root.errorMessage = message
      else Quickshell.execDetached(["notify-send", "--", "Launcher dictation", message])
    }
  }
  function dictationAccept(alternate) {
    if (clipboardTransfer.busy) return
    if (voice.active) {
      if (!root.dictationPending) root.dictationPending = alternate ? "paste" : "copy"
      root.voiceStop()
    } else clipboardTransfer.submit(search.text, alternate)
  }
  property string voiceRawText: ""
  readonly property bool liveText: voice.active && search.text.length > 0
  function voiceLive(text) {
    if (!root.opened || voice.phase !== "listening" || root.voiceDiscard) return
    if (root.providerViewActive && providerView.item) { if (typeof providerView.item.transcript === "function") providerView.item.transcript(text, false); return }
    root.voiceRawText = String(text || "")
    var t = root.dictationMode ? String(text || "") : String(text || "").replace(/\s+/g, " ").trim()
    if (t === search.text) return
    search.text = t
    search.cursorPosition = t.length
    root.edited()
  }
  function installVoiceBindings() {
    if (!root.bindingsKnown) { root.errorMessage = "Could not read " + root.bindingsPath; return }
    root.confirmPending = {
      message: "Write voice hotkeys to " + root.bindingsPath + "?",
      confirmText: "Write bindings",
      run: function() {
        var next = VoiceBindings.apply(root.bindingsText, root.voiceSettings.keys)
        root.writeFile(bindingsFile, next, root.home + "/.config/hypr", function() {
          root.bindingsText = next
          root.statusMessage = "Voice bindings saved · reload Hyprland to apply"
          root.requery()
        })
      }
    }
  }
  function voiceBegin(trigger) {
    if (!root.voiceEnabled || !root.opened || root.dmenuActive || root.confirmPending || voice.active) return false
    root.voiceTrigger = trigger
    root.voiceDiscard = false
    root.voiceRawText = ""
    root.dictationPending = ""
    if (root.providerViewActive && providerView.item && typeof providerView.item.beginVoice === "function") providerView.item.beginVoice()
    else { search.text = ""; root.edited() }
    root.errorMessage = ""
    root.statusMessage = ""
    var started = voice.start()
    return started
  }
  function voiceStop() { if (voice.phase === "starting" || voice.phase === "listening") voice.stop() }
  function voiceCancel() {
    root.voiceRawText = ""
    root.dictationPending = ""
    root.voiceDiscard = true
    if (voice.active) voice.cancel()
  }
  function voiceTranscribed(raw) {
    if (!root.opened || root.voiceDiscard) return
    if (root.providerViewActive && providerView.item) { if (typeof providerView.item.transcript === "function") providerView.item.transcript(raw, true); return }
    root.voiceRawText = String(raw || "")
    var text = root.dictationMode ? String(raw) : Intent.normalize(raw)
    search.text = text
    search.cursorPosition = text.length
    root.edited()
    if (root.dictationMode) {
      var pendingCopy = root.dictationPending
      root.dictationPending = ""
      root.statusMessage = "Enter copies · Ctrl+Enter pastes"
      if (pendingCopy) clipboardTransfer.submit(text, pendingCopy === "paste")
    } else root.statusMessage = "Transcribed · press ↵ to run"
  }
  function isSuperKey(key) { return key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R }
  function isModifierKey(key) {
    return root.isSuperKey(key) || key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt || key === Qt.Key_AltGr || key === Qt.Key_CapsLock
  }

  // -------------------------------------------------------------- frecency
  property var usage: ({})
  FileView {
    id: usageFile
    path: root.usagePath
    atomicWrites: true
    printErrors: false
    onLoaded: root.usage = Frecency.parse(text())
    onLoadFailed: root.usage = ({})
    onSaved: root.written(true)
    onSaveFailed: root.written(false)
  }
  function remember(row) {
    if (!row.remember) return
    var now = Date.now() / 1000
    var next = Frecency.record(root.usage, Frecency.key(row.providerKey, row.id), now)
    var queryKey = Frecency.queryKey(row.providerKey, row.id, root.voiceRawText || search.text, root.scope)
    if (queryKey) next = Frecency.record(next, queryKey, now)
    root.usage = next
    root.writeFile(usageFile, Frecency.serialize(root.usage), root.stateDir)
  }
  function bonusFor(row) {
    if (!row.remember) return 0
    var now = Date.now() / 1000
    return Frecency.bonus(root.usage, Frecency.key(row.providerKey, row.id), now)
      + Frecency.queryBonus(root.usage, Frecency.queryKey(row.providerKey, row.id, root.voiceRawText || search.text, root.scope), now)
  }

  // ----------------------------------------------------------------- state
  property bool opened: false
  property string mode: "palette"           // palette | select | input
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property string fontFamily: "Adwaita Sans"
  readonly property string monoFamily: "Monaspace Argon"
  property string scope: ""
  property string scopeTitle: ""
  property var history: []
  property var rows: []
  property var uids: []
  property int selected: 0
  onSelectedChanged: root.syncCurrent()
  property bool selectionTouched: false
  // While Ctrl is down the first rows show their Ctrl+digit in place of the
  // icon. Cleared on open: a launch under Ctrl+digit never sees the release.
  property bool ctrlHeld: false
  readonly property int shortcutRows: 8
  property int generation: 0
  property bool pending: false
  property bool showLoading: false
  property string errorMessage: ""
  property string statusMessage: ""
  property var confirmPending: null       // { message, confirmText, run }
  // A confirm opened by a Ctrl chord (Ctrl+Delete, Ctrl+B) takes the focus,
  // so the field never sees Ctrl come up: drop the Ctrl+digit badges here.
  onConfirmPendingChanged: if (root.confirmPending) root.ctrlHeld = false
  readonly property var current: rows.length && selected >= 0 && selected < rows.length ? rows[selected] : ({})
  readonly property bool compact: paletteSettings.density !== "comfortable"
  readonly property color accent: Tokens.accent
  readonly property int shellRadius: Theme.panelRadius
  readonly property int controlRadius: Theme.controlRadius
  readonly property string headingFamily: Theme.headingFont
  readonly property bool clipboardChoice: root.dictationMode || !!(root.current.action && root.current.action.type === "dictation-copy")
  readonly property bool previewVisible: !dmenuActive && paletteSettings.showPreview !== false && root.usefulPreview(current)
  function usefulPreview(row) {
    if (!row || row.providerKey === "applications") return false
    if (row.previewImage || row.swatch) return true
    if (!row.preview) return false
    if (row.providerKey === "hotkeys" || row.providerKey === "extensions" || row.providerKey === "settings") return false
    var preview = String(row.preview || "")
    return preview !== String(row.title || "") && preview !== String(row.subtitle || "") && preview !== String(row.hint || "") && preview !== String(row.previewDetail || "")
  }

  // ---------------------------------------------------------------- motion
  // Three tiers (core/Motion.js) drive every transition: the window's
  // reveal, a menu level entering, the selection gliding and the activated
  // row's flash. A duration of 0 turns a transition into a plain assignment.
  readonly property var motion: Motion.profile(paletteSettings.animations)
  readonly property bool windowSlides: paletteSettings.windowTransition === "slide"
  // The window transition is chosen apart from the tier: Instant keeps the
  // rest of the palette animated while the window itself appears at once.
  readonly property int windowDuration: paletteSettings.windowTransition === "instant" ? 0 : motion.window
  // 0 hidden … 1 shown; the card follows it. The layer stays
  // mapped, without keyboard focus, while `closing` runs it back down.
  property real reveal: 0
  property bool closing: false
  property double flashUntil: 0             // wall clock at which the activated row's flash peaks
  signal flashed(string uid)
  onOpenedChanged: {
    hideDelay.stop()
    revealAnim.stop()
    if (root.opened) {
      root.closing = false
      if (root.windowDuration > 0) { revealAnim.to = 1; revealAnim.duration = root.windowDuration; revealAnim.restart() }
      else root.reveal = 1
    } else if (root.windowDuration > 0) {
      // Leaving waits for the flash to peak, so a launch still reads as "that row".
      root.closing = true
      hideDelay.interval = Math.max(0, root.flashUntil - Date.now())
      hideDelay.restart()
    } else { root.reveal = 0; root.closing = false }
  }
  Timer { id: hideDelay; onTriggered: { if (root.opened) return; revealAnim.to = 0; revealAnim.duration = root.windowDuration; revealAnim.restart() } }
  // Most of the change lands in the first frames: a reveal that ramps up
  // gently reads as the palette being late, not as motion.
  NumberAnimation {
    id: revealAnim; target: root; property: "reveal"; easing.type: Easing.OutExpo
    onFinished: if (!root.opened && revealAnim.to === 0) root.closing = false
  }
  function flash(uid) {
    if (root.motion.flashRise + root.motion.flashFall <= 0 || !uid) return
    root.flashUntil = Date.now() + root.motion.flashRise
    root.flashed(uid)
  }
  // A menu level enters from the side it lives on: a deeper screen from the
  // right, the parent from the left. Only the entering level moves; rows are
  // reconciled in place, so there is no outgoing copy to slide away.
  property real levelOpacity: 1
  Translate { id: levelShift }
  function slideLevel(direction) {
    if (root.motion.slide <= 0 || !root.opened) return
    levelAnim.stop()
    levelShift.x = Motion.levelOffset(direction, Style.space(Motion.LEVEL_SLIDE_PX))
    root.levelOpacity = 0
    levelAnim.duration = root.motion.slide
    levelAnim.restart()
  }
  ParallelAnimation {
    id: levelAnim
    property int duration: 0
    NumberAnimation { target: levelShift; property: "x"; to: 0; duration: levelAnim.duration; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "levelOpacity"; to: 1; duration: levelAnim.duration; easing.type: Easing.OutQuad }
  }

  // The island's tokens (main-tokens 1.3, launcher-pickers 5.5). Provider
  // views (Codex, Settings, the device menus) paint with these through host.
  readonly property color background: Tokens.surface
  readonly property color foreground: Tokens.fg
  readonly property color scrim: Tokens.scrim
  readonly property color selectedBackground: Tokens.accentTint
  readonly property color selectedText: Tokens.fg
  readonly property color hairline: Tokens.hairline
  readonly property color muted: Tokens.inkDim
  readonly property color danger: Tokens.bad
  readonly property color raised: Tokens.raised
  readonly property color fillLow: Tokens.fillLow
  readonly property color fillHigh: Tokens.fillHigh
  // The Codex view's repo chip: the focused window's repository and branch
  // (Context's git probe), "" when it is not in one. Read only while a
  // provider view shows, so the palette alone never starts Context.
  // The sandbox has no focused window, so a fixture's launcherRepo
  // ({ name, branch }) stands in for Context there.
  readonly property var fixtureRepo: Fixture.data.launcherRepo ?? null
  readonly property string repoName: root.fixtureRepo ? String(root.fixtureRepo.name || "")
    : root.providerViewActive && Context.top ? String(Context.top).replace(/\/+$/, "").split("/").pop() : ""
  readonly property string repoBranch: root.fixtureRepo ? String(root.fixtureRepo.branch || "")
    : root.providerViewActive && Context.top ? Context.branch : ""

  // Type scale for provider views. A view covers the whole card, so it has to
  // carry the palette's own sizes -- including the density bump -- or it reads
  // a step smaller than the results it replaced. Ladder: fontInput is the
  // search field, fontTitle a row title, fontBody a preview body, fontLabel a
  // row subtitle or footer, fontCaption a keycap or the breadcrumb brand.
  // The island's sizes (launcher-pickers 4): the query 16, row titles 13,
  // bodies 13, subtitles and the footer 11 or 12, keycaps 11.
  readonly property int fontInput: 16
  readonly property int fontTitle: 13
  readonly property int fontBody: 13
  readonly property int fontLabel: 12
  readonly property int fontCaption: 11
  // Tells a provider view it need not paint its own backdrop; an older
  // host leaves this undefined, so a view can still fall back.
  readonly property bool paintsViewBackdrop: true

  onPendingChanged: { if (pending) loadingDelay.restart(); else { loadingDelay.stop(); showLoading = false } }
  Timer { id: loadingDelay; interval: 180; onTriggered: root.showLoading = root.pending }
  Timer { id: debounce; interval: 25; onTriggered: root.runQuery() }

  Providers.Registry { id: providerRegistry; host: root }
  readonly property var registry: providerRegistry
  ListModel { id: resultModel }
  PointerMoveGate { id: pointerGate; referenceItem: root.viewItem }

  // ---------------------------------------------------------------- opening
  function resetSelection() {
    root.selectionTouched = false
    root.selected = 0
    root.ctrlHeld = false
    pointerGate.reset()
  }

  function openRoute(input, payload) {
    root.endCapture()
    root.closeProviderView()
    clipboardTransfer.cancel()
    if (root.dmenuActive && root.requestActive) root.finishRequest(null)
    var inputScope = String(payload && payload.scope !== undefined ? payload.scope : input || "root")
    var direct = root.registryEntry(inputScope.split("/")[0])
    var route = direct && (direct.key !== "system" || inputScope === "system" || inputScope === "system/root")
                ? { kind: "scope", scope: inputScope, label: direct.provider.name }
                : providerRegistry.bundled[0].routeFor(inputScope)
    route = route || { kind: "menu", id: "root" }
    root.voiceCancel()
    root.mode = "palette"
    root.requestActive = false
    root.history = []
    root.confirmPending = null
    root.errorMessage = ""
    root.statusMessage = ""
    if (route.scope !== undefined && route.kind !== "action") {
      root.scope = String(route.scope); root.scopeTitle = String(route.label || route.title || "")
    } else if (route.kind === "apps") {
      root.scope = "applications"; root.scopeTitle = "Applications"
    } else if (route.kind !== "action" && route.id && route.id !== "root") {
      root.scope = route.id === "system" || route.id.indexOf("system/") === 0 ? route.id : "system/" + route.id
      root.scopeTitle = route.label || "System"
    } else {
      root.scope = ""; root.scopeTitle = ""
    }
    if (payload && payload.title) root.scopeTitle = String(payload.title)
    search.text = payload && payload.query !== undefined ? String(payload.query) : String(route.query || "")
    root.resetSelection()
    root.applyRows([])
    root.opened = true
    root.notifyOpened()
    root.runQuery()
    // Routes identify canonical provider rows, not an alternate execution API.
    // Unknown actions stay inert rather than bypassing a row's confirmation.
    if (route.kind === "action") root.activateRoute(route)
    Qt.callLater(function() {
      if (!root.confirmPending) search.forceActiveFocus()
      if (root.opened && root.dictationMode && payload && payload.dictate === true) root.voiceBegin("tap")
    })
  }

  function activateRoute(route) {
    var entry = root.registryEntry("system")
    if (!entry || !root.providerEnabled(entry)) { root.errorMessage = "System provider is disabled"; return }
    var ctx = { query: "", rawQuery: "", scope: "", sub: "", settings: root.settingsFor(entry), host: root,
                generation: root.generation, pending: function() {}, shell: root.shell, appLibrary: root.appLibrary, omarchyPath: root.omarchyPath }
    var catalog = entry.provider.catalog ? entry.provider.catalog(ctx) : entry.provider.query(ctx)
    var row = (catalog || []).find(function(candidate) {
      return route.id ? candidate.id === route.id : route.row ? candidate.id === route.row.id
        : route.action && JSON.stringify(candidate.action) === JSON.stringify(route.action)
    })
    if (!row || row.disabled) { root.errorMessage = "Route action is unavailable"; return }
    root.activateRow(root.normalize(row, entry, "", 0), false)
  }

  function notifyOpened() {
    root.invalidateCatalog()
    providerRegistry.rebuild()
    providerRegistry.scan()
    for (var i = 0; i < providerRegistry.entries.length; i++) {
      var p = providerRegistry.entries[i].provider
      if (typeof p.opened === "function") { try { p.opened() } catch (e) { console.warn("keystroke: provider opened() threw", e) } }
    }
    voice.refresh()
  }

  function openDmenu(payload) {
    var selectionPath = String(payload.selectionFile || ""), donePath = String(payload.doneFile || "")
    if (!root.validPickerPath(selectionPath) || !root.validPickerPath(donePath) || selectionPath === donePath) {
      root.errorMessage = "Picker completion files must be inside " + root.pickerDir + "/"
      return false
    }
    matchingSession.cancelRequest()
    root.endCapture()
    root.closeProviderView()
    clipboardTransfer.cancel()
    if (root.dmenuActive && root.requestActive) root.finishRequest(null)   // a new caller cancels the previous one
    root.voiceCancel()
    root.mode = payload.mode === "input" ? "input" : "select"
    root.dmenuPrompt = String(payload.prompt || (root.mode === "input" ? "Input" : "Select"))
    root.dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    root.selectionFile = selectionPath
    root.doneFile = donePath
    root.requestActive = !!root.doneFile
    root.dmenuWidth = Math.max(1, Number(payload.width || 300))
    root.dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    root.scope = ""; root.scopeTitle = root.dmenuPrompt; root.history = []
    root.confirmPending = null
    search.text = ""
    root.resetSelection()
    root.applyRows([])
    root.opened = true
    root.runQuery()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  readonly property string pickerDir: xdgPath("XDG_RUNTIME_DIR", "") ? xdgPath("XDG_RUNTIME_DIR", "") + "/quickshell-launcher" : ""
  function validPickerPath(path) {
    if (!root.pickerDir || path.indexOf(root.pickerDir + "/") !== 0 || path.indexOf("\u0000") >= 0) return false
    return path.slice(root.pickerDir.length + 1).split("/").every(function(part) { return part && part !== "." && part !== ".." })
  }
  // Open each directory without following symlinks. Atomic replacement also
  // avoids following existing leaf symlinks or modifying hard-linked files.
  // Picker data travels in argv, never in executable source.
  readonly property string pickerWriterPath: decodeURIComponent(Qt.resolvedUrl("helpers/picker-write.lua").toString().replace(/^file:\/\//, ""))
  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) return
    var selectionPath = root.selectionFile, donePath = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""
    if (!root.validPickerPath(selectionPath) || !root.validPickerPath(donePath)) return
    var accepted = selection !== null && selection !== undefined
    Quickshell.execDetached(["luajit", root.pickerWriterPath, root.pickerDir, selectionPath, donePath, accepted ? "1" : "0", accepted ? String(selection) : ""])
  }

  function cancel(preserveTransfer) {
    matchingSession.cancelRequest()
    root.endCapture()
    root.closeProviderView()
    if (preserveTransfer !== true) clipboardTransfer.cancel()
    if (root.dmenuActive) root.finishRequest(null)
    root.voiceCancel()
    root.opened = false
    root.confirmPending = null
    root.pending = false
    debounce.stop()
  }

  // ---------------------------------------------------------------- queries
  function edited() {
    root.confirmPending = null
    root.resetSelection()
    debounce.restart()
  }
  function setQuery(text) { clipboardTransfer.cancel(); root.voiceCancel(); search.text = String(text || ""); root.edited(); return "ok" }

  // Providers call this when asynchronous results land; the selection is kept.
  // Their Smart Match catalog is enumerated again unless the caller says it did
  // not change ({ catalog: false }). Calls landing in one event-loop turn run a
  // single query, and none cuts short the typing pause: the pending query reads
  // the latest data when the user pauses.
  function requery(options) {
    if (!options || options.catalog !== false) root.invalidateCatalog()
    else root.invalidateProviders(options.provider)
    if (!root.opened || debounce.running) return
    refresh.start()
  }

  // Provider rows are kept per provider for the current query and scope, so a
  // refresh caused by one provider (fd finished, a reply landed) re-runs only
  // that provider. A requery() without a provider key drops every entry.
  property var providerCache: ({})
  function invalidateProviders(key) {
    if (key) delete root.providerCache[String(key)]
    else root.providerCache = ({})
  }
  Timer { id: refresh; interval: 0; onTriggered: if (!debounce.running) root.runQuery() }

  // ------------------------------------------------------ Smart Match catalog
  // Providers enumerate their catalog only when something may have changed: a
  // provider reported new data through requery(), the palette opened, the
  // registry or configuration changed, or the scope differs. Every keystroke
  // reuses the rows; the documents filtered under one set of intent
  // constraints are reused by every query sharing those constraints.
  property var catalogCache: null
  function invalidateCatalog() {
    root.catalogCache = null
    root.invalidateProviders()
    // The first keystroke should not pay for the enumeration: build it while
    // the palette sits open with nothing typed.
    if (root.opened && !root.dmenuActive) prewarm.restart()
  }
  Timer {
    id: prewarm; interval: 0
    onTriggered: {
      if (!root.opened || root.dmenuActive || root.providerViewActive || root.catalogCache) return
      if (!SmartMatch.enabled(root.matchingSettings.mode, !!root.voiceRawText)) return
      var sc = root.scope, owner = sc.split("/")[0]
      root.catalogFor(sc, owner, sc.indexOf("/") >= 0 ? sc.slice(owner.length + 1) : "")
    }
  }
  function catalogFor(scope, owner, sub) {
    var cache = root.catalogCache
    if (cache && cache.scope === scope) return cache
    var rows = [], seen = ({}), pend = false, mark = function() { pend = true }
    for (var i = 0; i < providerRegistry.entries.length; i++) {
      var entry = providerRegistry.entries[i]
      if (!root.providerEnabled(entry)) continue
      if (scope && owner !== entry.key) continue
      var ctx = { query: "", rawQuery: "", scope: scope, sub: scope ? sub : "", generation: root.generation, settings: root.settingsFor(entry),
                  patterns: Patterns.evaluate(entry.patterns, ""), pending: mark, host: root, shell: root.shell, appLibrary: root.appLibrary, omarchyPath: root.omarchyPath }
      try {
        var candidates = []
        if (typeof entry.provider.catalog === "function") candidates = entry.provider.catalog(ctx) || []
        else if (!scope && entry.source === "bundled") {
          // Older providers contribute only navigation rows, never arbitrary
          // clipboard/file content or executable results from an empty query.
          candidates = (entry.provider.query(ctx) || []).filter(function(c) { return c.action && c.action.type === "navigate" })
        }
        for (var c = 0; c < candidates.length && rows.length < 6000; c++) {
          var candidate = root.normalize(candidates[c], entry, "", 0)
          if (!candidate || candidate.disabled || candidate.tier !== "item" || seen[candidate.uid]) continue
          seen[candidate.uid] = true
          rows.push(root.describe(candidate))
        }
      } catch (e) { console.warn("keystroke: provider", entry.key, "catalog failed:", e) }
    }
    cache = { scope: scope, rows: rows, pending: pend, chrome: SmartMatch.hasChrome(rows), documents: ({}), documentKeys: [], lexical: { text: null, scores: null } }
    root.catalogCache = cache
    return cache
  }
  function documentsFor(cache, req) {
    var key = SmartMatch.constraintKey(req), hit = cache.documents[key]
    if (hit) return hit
    if (cache.documentKeys.length >= 16) { cache.documents = ({}); cache.documentKeys = [] }
    hit = SmartMatch.documents(cache.rows, req)
    cache.documents[key] = hit
    cache.documentKeys.push(key)
    return hit
  }

  function runQuery() {
    if (!root.opened || root.providerViewActive) return
    debounce.stop(); refresh.stop()
    if (root.dmenuActive) { root.matchQuery = ""; root.applyRows(root.dmenuRows()); root.pending = false; root.afterRows(); return }
    root.generation++
    var raw = root.voiceRawText || search.text, sc = root.scope
    var filePrefix = !root.dictationMode && (!sc || sc === "files") && FileSearch.prefixed(raw)
    var smart = !root.dictationMode && !filePrefix && SmartMatch.enabled(root.matchingSettings.mode, !!root.voiceRawText)
    var req = SmartMatch.request(raw)
    // Provider queries keep case and arguments (paths, units, extension input).
    // Command rewrites belong to catalog matching.
    var q = root.voiceRawText && !root.dictationMode ? Intent.normalize(root.voiceRawText) : search.text
    var owner = sc.split("/")[0]
    var sub = sc.indexOf("/") >= 0 ? sc.slice(owner.length + 1) : ""
    var collected = [], errors = [], pend = false, matchedPatterns = ({})
    var cacheKey = [q, root.voiceRawText || search.text, sc, root.dictationMode ? "d" : ""].join("\u001f")
    for (var i = 0; i < providerRegistry.entries.length; i++) {
      var entry = providerRegistry.entries[i]
      if (!root.providerEnabled(entry)) continue
      if (filePrefix && entry.key !== "files") continue
      if (sc && owner !== entry.key) continue
      var cached = root.providerCache[entry.key]
      if (!cached || cached.key !== cacheKey) {
        cached = root.queryProvider(entry, q, sc, sub)
        cached.key = cacheKey
        root.providerCache[entry.key] = cached
      }
      for (var r = 0; r < cached.rows.length; r++) collected.push(cached.rows[r])
      if (cached.pending) pend = true
      if (cached.patterns) matchedPatterns[entry.key] = cached.patterns
      if (cached.error) errors.push(cached.error)
    }
    if (root.configError) errors.push(root.configError)
    if (smart && q) {
      // A blocked request sends nothing to the matching helper.
      var catalog = !req.blocked ? root.catalogFor(sc, owner, sub) : null
      var documents = catalog ? root.documentsFor(catalog, req) : { rows: [], signature: "" }
      var matchKey = JSON.stringify([raw, sc, root.matchingSettings.model, documents.signature])
      var hasAnswer = collected.some(function(r) { return r.tier === "answer" })
      if (documents.rows.length && !hasAnswer && raw.length <= 1024) matchingSession.submit(matchKey, raw, documents.rows, documents.signature)
      else matchingSession.cancelRequest()
      if (catalog && catalog.pending) pend = true
      collected = SmartMatch.merge(collected, catalog ? catalog.rows : [], req, matchingSession.resultKey === matchKey ? matchingSession.matches : [],
                                   catalog ? catalog.chrome : false, catalog ? catalog.lexical : null)
    } else matchingSession.cancelRequest()
    var ranked = Match.rank(collected, root.bonusFor)
    root.matchQuery = root.dictationMode ? "" : q
    // The clipboard scope lists its whole history (the provider's limit, up
    // to 300), as the old picker did; elsewhere the best 120.
    var shown = ranked.slice(0, sc === "clipboard" ? 300 : 120)
    // A query or a scope can mix sections, and the view then draws a header
    // per section: gather each section under its best row (Match.groupSections).
    if (q || sc) shown = Match.groupSections(shown)
    root.applyRows(shown)
    root.lastPatterns = matchedPatterns
    root.pending = pend || (smart && matchingSession.requestedKey !== "" && matchingSession.busy)
    if (smart && matchingSession.error) errors.push(matchingSession.error)
    root.errorMessage = errors.join(" · ")
    root.afterRows()
  }

  // One provider's rows for one query: normalized, bounded, with whether it
  // asked for a later refresh and which declared patterns matched.
  function queryProvider(entry, q, sc, sub) {
    var result = { rows: [], pending: false, patterns: null, error: "" }
    // Declared patterns run before query(): the provider learns which shapes
    // matched, and the largest boost lifts every row it returns this time.
    var patterns = Patterns.evaluate(entry.patterns, q)
    if (patterns.matched.length) result.patterns = patterns.matched
    var ctx = { query: q, rawQuery: root.voiceRawText || search.text, scope: sc, sub: sc ? sub : "", generation: root.generation, settings: root.settingsFor(entry),
                patterns: patterns, pending: function() { result.pending = true }, host: root, shell: root.shell, appLibrary: root.appLibrary, omarchyPath: root.omarchyPath }
    try {
      var out = entry.provider.query(ctx) || []
      for (var r = 0; r < out.length && r < 400; r++) {
        var row = root.normalize(out[r], entry, q, patterns.boost)
        if (row) result.rows.push(row)
      }
    } catch (e) {
      result.error = entry.provider.name + ": " + e
      console.warn("keystroke: provider", entry.key, "failed:", e)
    }
    return result
  }

  property var lastPatterns: ({})           // provider key → matched pattern ids, for inspect()
  function normalize(row, entry, q, boost) {
    if (!row || typeof row !== "object" || typeof row.title !== "string") return null
    var out = {}
    for (var k in row) out[k] = row[k]
    out.id = String(row.id === undefined ? row.title : row.id)
    out.providerKey = entry.key
    out.providerName = entry.provider.name
    out.source = entry.source
    out.uid = entry.key + "/" + out.id
    out.subtitle = String(row.subtitle || "")
    out.icon = String(row.icon || "⌘")
    out.iconFont = String(row.iconFont || "")
    out.iconSource = String(row.iconSource || "")
    out.tint = String(row.tint || "")
    out.section = String(row.section || entry.provider.name)
    out.verb = String(row.verb || (row.action && row.action.type === "navigate" ? "Open" : "Run"))
    out.tier = row.tier === "answer" || row.tier === "fallback" ? row.tier : "item"
    var base = typeof row.score === "number" ? row.score : Match.match(q, row.title, row.keywords || "", row.path || "", row.description || "")
    // A matched provider pattern lifts rows that already match; it never revives a row the matcher dropped.
    out.score = q && base > 0 && boost > 0 ? base + boost : base
    out.accessory = String(row.accessory || "")
    if (!out.accessory && root.hotkeysByRoute[out.uid]) out.accessory = UserHotkeys.display(root.hotkeysByRoute[out.uid].combo)
    out.badge = String(row.badge || (entry.source === "community" ? "plugin" : ""))
    out.hint = String(row.hint || "")
    out.disabled = row.disabled === true
    out.remember = row.remember === true
    out.confirm = String(row.confirm || "")
    if (q && !(base > 0)) return null
    return out
  }

  function dmenuRows() {
    if (root.mode === "input") return []
    var q = search.text.trim().toLowerCase(), rows = []
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (q && label.toLowerCase().indexOf(q) < 0 && detail.toLowerCase().indexOf(q) < 0) continue
      rows.push({ id: String(i), uid: "dmenu/" + i, title: label, subtitle: detail, icon: icon, iconFont: "", iconSource: "", tint: "",
                  section: "", verb: "Select", tier: "item", score: 1, order: i, accessory: "", badge: "", hint: "", disabled: false,
                  remember: false, confirm: "", providerKey: "dmenu", value: detail ? label + "\t" + detail : label })
    }
    return rows
  }

  // Every key is always set: a ListModel fixes its roles at the first insert.
  function display(row, index, previousSection) {
    return { uid: row.uid, providerKey: row.providerKey, title: row.title, subtitle: row.subtitle, icon: row.icon, iconFont: row.iconFont, iconSource: row.iconSource,
             tint: row.tint, section: row.section, sectionStart: row.section !== previousSection, verb: row.verb, accessory: row.accessory,
             disabled: row.disabled, badge: row.badge, answer: row.tier === "answer", hint: row.hint,
             ranges: root.rangesFor(row), glyph: Glyphs.forRow(row), meta: String(row.meta || ""), mono: row.mono === true }
  }

  // Reconcile by uid so delegates update in place while typing.
  function applyRows(next) {
    var selectedUid = root.selectionTouched && root.current ? root.current.uid : ""
    var wanted = ({})
    for (var n = 0; n < next.length; n++) wanted[next[n].uid] = true
    var order = root.uids.slice()
    for (var j = order.length - 1; j >= 0; j--) {
      if (!wanted[order[j]]) { resultModel.remove(j); order.splice(j, 1) }
    }
    var previous = ""
    for (var i = 0; i < next.length; i++) {
      var uid = next[i].uid
      var d = root.display(next[i], i, previous)
      previous = next[i].section
      var at = order.indexOf(uid, i)
      if (at < 0) { resultModel.insert(i, d); order.splice(i, 0, uid) }
      else {
        if (at !== i) { resultModel.move(at, i, 1); order.splice(i, 0, order.splice(at, 1)[0]) }
        resultModel.set(i, d)
      }
    }
    root.uids = order
    root.rows = next
    if (selectedUid) {
      for (var s = 0; s < next.length; s++) if (next[s].uid === selectedUid) { root.selected = s; break }
    }
    root.syncCurrent()
  }

  // The list follows a surviving item when rows above the selection are
  // removed, so its own index drifts from `selected` while typing; the
  // highlight reads the list's current item, so re-assert the index after
  // every reconcile and whenever the selection moves.
  function syncCurrent() {
    resultList.sync(root.selected)
  }

  function afterRows() {
    if (root.selectionTouched) {
      var keep = root.current && root.current.uid
      var found = -1
      for (var i = 0; i < root.rows.length && keep; i++) if (root.rows[i].uid === keep) { found = i; break }
      root.selected = found >= 0 ? found : Math.max(0, Math.min(root.selected, root.rows.length - 1))
    } else {
      root.selected = 0
      resultList.positionViewAtBeginning()
    }
    root.syncCurrent()
  }

  // ------------------------------------------------------------- navigation
  function navigate(nextScope, title) {
    clipboardTransfer.cancel()
    root.voiceCancel()
    root.history = root.history.concat([{ scope: root.scope, title: root.scopeTitle, query: search.text }])
    root.scope = nextScope
    root.scopeTitle = title || ""
    search.text = ""
    root.resetSelection()
    root.applyRows([])
    root.runQuery()
    resultList.positionViewAtBeginning()
    root.slideLevel(1)
  }

  function goBack() {
    clipboardTransfer.cancel()
    if (root.confirmPending) { root.confirmPending = null; return true }
    if (root.dmenuActive) return false
    var priorRawQuery = root.providerViewRawQuery
    root.voiceCancel()
    if (root.providerViewActive) {
      root.closeProviderView()
      root.voiceRawText = priorRawQuery
      root.runQuery()
      search.forceActiveFocus()
      root.slideLevel(-1)
      return true
    }
    if (root.history.length) {
      var prior = root.history[root.history.length - 1]
      root.history = root.history.slice(0, -1)
      root.scope = prior.scope; root.scopeTitle = prior.title; search.text = prior.query
    } else if (root.scope) {
      root.scope = ""; root.scopeTitle = ""; search.text = ""
    } else return false
    root.resetSelection()
    root.applyRows([])
    root.runQuery()
    resultList.positionViewAtBeginning()
    root.slideLevel(-1)
    return true
  }

  function select(delta) {
    if (!root.rows.length) return
    root.selectionTouched = true
    pointerGate.reset()
    root.selected = (root.selected + Number(delta) + root.rows.length) % root.rows.length
    resultList.positionViewAtIndex(root.selected, ListView.Contain)
  }

  function selectPage(delta) {
    if (!root.rows.length) return
    root.selectionTouched = true
    pointerGate.reset()
    root.selected = Math.max(0, Math.min(root.rows.length - 1, root.selected + Number(delta)))
    resultList.positionViewAtIndex(root.selected, ListView.Contain)
  }

  // Ctrl+1…Ctrl+8: select the nth visible row and run it in one stroke.
  // A number past the end of the list does nothing rather than acting on
  // whatever happens to be selected.
  function activateAt(index) {
    if (root.dictationMode || root.mode === "input") return
    if (index < 0 || index >= root.rows.length) return
    root.selectionTouched = true
    pointerGate.reset()
    root.selected = index
    resultList.positionViewAtIndex(root.selected, ListView.Contain)
    root.activate()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.selectionTouched = true
    root.selected = index
  }

  // --------------------------------------------------------------- actions
  // True while a pointer (a row's click, the card's Run) runs the activation:
  // a provider view it opens waits for a key before drawing its focus ring
  // (the System view's control center sheets, main-tokens 2.6). Keys run
  // activate() itself.
  property bool pointerActivation: false
  function activateFromPointer(alternate) {
    root.pointerActivation = true
    try { root.activate(alternate) } finally { root.pointerActivation = false }
  }
  // Ctrl+↵ is the alternate activation: a row's altAction when it has one,
  // otherwise its action; the provider's activate() sees ctx.alternate.
  function activate(alternate) {
    if (root.confirmPending) return
    if (root.dictationMode) { root.dictationAccept(alternate); return }
    if (debounce.running || refresh.running) root.runQuery()
    if (root.dmenuActive) {
      if (root.mode === "input") { root.applyDmenuSelection(search.text); return }
      if (root.rows.length) { root.flash(root.current.uid); root.applyDmenuSelection(root.current.value) }
      return
    }
    var row = root.current
    if (!row || !row.uid || row.disabled) return
    if (row.smartMatch) {
      var selectedId = row.uid
      root.runQuery()
      row = root.rows.filter(function(r) { return r.uid === selectedId })[0]
      if (!row || row.disabled) return
    }
    root.activateRow(row, alternate)
  }

  // headless: a palette hotkey ran the row; nothing flashes and usage is not recorded.
  function activateRow(row, alternate, headless) {
    if (!row || row.disabled || root.confirmPending) return
    var entry = root.registryEntry(row.providerKey)
    if (!entry || !root.providerEnabled(entry)) return
    var action = alternate && row.altAction ? row.altAction : row.action
    var confirmation = alternate && row.altAction && row.altConfirm !== undefined ? String(row.altConfirm) : row.confirm
    // Voice binding installation owns its confirmation, including direct calls.
    if (action && action.type === "voice-bindings") { root.installVoiceBindings(); return }
    if (action && action.type === "unbind-hotkey") { root.removeHotkey(action.route, action.label, action.combo); return }
    var run = function() {
      var currentEntry = root.registryEntry(row.providerKey)
      if (!currentEntry || currentEntry.provider !== entry.provider || !root.providerEnabled(currentEntry)) return
      var effect = action
      if (typeof currentEntry.provider.activate === "function") {
        try { effect = currentEntry.provider.activate(row, { host: root, settings: root.settingsFor(currentEntry), alternate: alternate === true, confirmed: !!confirmation }) || effect }
        catch (e) { root.errorMessage = currentEntry.provider.name + ": " + e; return }
      }
      if (!effect) return
      if (!headless) { root.flash(row.uid); root.remember(row) }
      root.perform(effect, row)
    }
    if (confirmation) root.confirmPending = { message: confirmation, confirmText: "Confirm", run: run }
    else run()
  }

  function applyDmenuSelection(value) {
    root.opened = false
    root.finishRequest(value)
  }

  function requestUninstall() {
    var row = root.current
    if (!row || !row.appId || !root.appLibrary) return
    var id = row.appId, name = row.title
    root.confirmPending = { message: "Do you want to uninstall " + name + "?", confirmText: "Uninstall",
                            run: function() { root.cancel(); root.appLibrary.remove(id, name) } }
  }

  // Ctrl+Delete in the clipboard scope, or its footer hint: the old Super+V
  // picker's wipe of the whole history, now behind a confirm. ClipboardStore
  // (the shell's) runs it on the signal; the scope then reloads empty.
  signal clipboardWipeConfirmed()
  // An `island` effect (perform below): the host shows that island state.
  signal islandRequested(string state)
  function requestClipboardWipe() {
    if (!root.opened || root.scope !== "clipboard" || root.dmenuActive || root.confirmPending || root.capturing) return false
    root.confirmPending = { message: "Clear the whole clipboard history? This can't be undone.", confirmText: "Clear history",
                            run: function() { root.clipboardWipeConfirmed() } }
    return true
  }

  // Ctrl+K: the selected row's provider settings (Settings itself for a
  // setting row). Also under the detail card's Actions.
  function openProviderSettings() {
    if (root.dmenuActive) return
    var row = root.current
    var key = row.providerKey && row.providerKey !== "settings" ? "settings/" + row.providerKey : "settings"
    root.navigate(key, row.providerName || "Settings")
  }

  function perform(effect, row) {
    var type = effect.type
    if (type === "matching-retry") { matchingSession.retry(); root.requery(); return }
    if (type === "noop") return
    if (type === "provider-view") { root.showProviderView(effect.provider); return }
    if (type === "dictate") {
      root.navigate("dictation", "Dictate to Clipboard")
      if (!root.voiceBegin("tap")) root.errorMessage = "Voice is unavailable; check Settings › Voice"
      return
    }
    if (type === "dictation-copy") { clipboardTransfer.submit(effect.text, effect.paste); return }
    if (type === "navigate") { root.navigate(effect.scope, effect.title || row.title); return }
    if (type === "setting") {
      try {
        root.saveConfig(Settings.withValue(root.config, effect.path, effect.key, effect.value, effect.schema))
        root.statusMessage = "Saving…"
        if (root.scope.split("/").length > 2 && effect.schema && effect.schema.type === "enum") root.goBack()
        else root.requery()
      } catch (e) { root.errorMessage = String(e.message || e) }
      return
    }
    if (type === "compound") {
      for (var i = 0; i < effect.actions.length; i++) root.perform(effect.actions[i], row)
      return
    }
    if (type === "notify") { Quickshell.execDetached(["notify-send", "--", String(effect.headline || "Launcher"), String(effect.body || "")]); return }
    if (type === "voice-bindings") { root.installVoiceBindings(); return }
    if (type === "close") { root.cancel(); return }
    // An island state (the System provider's Open Control center): the host
    // (Launcher.qml) moves the island there first, so it morphs from the
    // palette straight to that state, then the palette closes.
    if (type === "island") { root.islandRequested(String(effect.state || "")); root.cancel(); return }
    // Everything below leaves the palette: drop the keyboard-grabbing layer first, like the stock menu.
    root.cancel()
    if (type === "shell") Util.execDetached(String(effect.command || ""))
    else if (type === "exec") Util.execArgv((effect.argv || []).map(String))
    else if (type === "url") Util.execArgv(["xdg-open", String(effect.url || "")])
    else if (type === "copy") Quickshell.execDetached(["wl-copy", "--", String(effect.text === undefined ? "" : effect.text)])
    else if (type === "app" && root.appLibrary) root.appLibrary.launch(effect.id, effect.name)
    else if (type === "edit") {
      if (root.configError) Util.execArgv(["xdg-open", root.configPath])
      else root.writeFile(configFile, Settings.serialize(root.config), root.configDir, function() { Util.execArgv(["xdg-open", root.configPath]) })
    }
  }


  function inspectConversation() {
    var provider = providerRegistry.bundled.find(x => x.provider.id === "codex")
    var c = provider ? provider.session : null
    if (!c) return JSON.stringify({ error: "Conversation provider is unavailable" })
    return JSON.stringify({ threadId: c.threadId, phase: c.phase, ready: c.server.ready, error: c.error, activity: c.activity, messages: c.messages, draft: c.draft, firstTextMs: c.firstTextMs, lastMs: c.lastMs })
  }
  function inspectApplications() {
    var entries = root.appLibrary ? root.appLibrary.sortedEntries("") : []
    return JSON.stringify({ shell: !!root.shell, shellPluginId: root.shell ? root.shell.pluginId : "",
      manifestId: root.manifest ? root.manifest.id : "", manifestKinds: root.manifest ? root.manifest.kinds : [],
      library: !!root.appLibrary, sharedLibrary: !!applicationLibrary.sharedLibrary, entries: entries.length,
      providerLibrary: !!providerRegistry.bundled[1].library,
      providerEntries: providerRegistry.bundled[1].library ? providerRegistry.bundled[1].library.sortedEntries("").length : -1 })
  }
  function inspect() {
    var appEntries = root.appLibrary ? root.appLibrary.sortedEntries("") : []
    var viewItem = providerView.item
    return JSON.stringify({ opened: root.opened, host: root.hostKind, attached: !!root.attachedView, mode: root.mode, view: root.activeProviderKey, scope: root.scope, query: search.text, count: root.rows.length,
      // A provider view's own report (the System view's sheet: its name, row, keys), else null.
      viewState: viewItem && viewItem.sheetState !== undefined ? viewItem.sheetState : null,
      titles: root.rows.map(function(r) { return r.title }), selected: root.selected, pending: root.pending, patterns: root.lastPatterns,
      current: { uid: root.current.uid || "", icon: root.current.icon || "", iconSource: root.current.iconSource || "", badge: root.current.badge || "", tier: root.current.tier || "" },
      modelCount: resultModel.count, providers: providerRegistry.entries.map(function(e) { return e.key }), problems: providerRegistry.problems,
      applications: { library: !!root.appLibrary, entries: appEntries.length },
      matching: { mode: root.matchingSettings.mode, model: root.matchingSettings.model, loaded: matchingSession.loaded, status: matchingSession.status, error: matchingSession.error },
      error: root.errorMessage, configError: root.configError, status: root.statusMessage,
      confirm: root.confirmPending ? String(root.confirmPending.confirmText || "") : "",
      actions: !!(root.attachedView && root.attachedView.cardItem && root.attachedView.cardItem.menuOpen),
      hotkeys: { path: root.hotkeysPath, known: root.hotkeysKnown, entries: root.hotkeys.entries, capturing: root.capturing, chord: root.captureChord, check: root.captureCheck },
      voice: { backend: "voxtype", state: voice.phase, trigger: root.voiceTrigger, enabled: root.voiceEnabled, detected: voice.detected, version: voice.version,
               command: voice.command, daemon: voice.daemonState, bindings: root.voiceBindingsStatus, frames: voice.history.length, live: voice.liveText } })
  }

  // ------------------------------------------------------------------ view
  // The palette's view is ui/LauncherContent.qml. Launcher.qml hosts it in
  // the island's `launcher` state (island mode) or in its free panel (pill,
  // full, rail). The engine above drives whichever content is showing through
  // three stand-ins, which that content registers its items with (attach()).
  // With nothing attached they keep their values, so the engine also runs
  // headless (palette hotkeys, tests, a host that has not built its view yet).
  QtObject {
    id: search
    property string text: ""
    property int cursorPosition: 0
    property Item field: null
    onCursorPositionChanged: if (field && field.cursorPosition !== cursorPosition) field.cursorPosition = Math.min(cursorPosition, field.text.length)
    function forceActiveFocus() { if (field) field.forceActiveFocus() }
  }
  QtObject {
    id: resultList
    property Item view: null
    property int currentIndex: -1
    // The list follows a surviving delegate when rows above it go, so its own
    // index can drift from `selected`; sync() puts it back either way.
    function sync(index) {
      currentIndex = index
      if (view && view.currentIndex !== index) view.currentIndex = index
    }
    function positionViewAtIndex(index, mode) { if (view && index >= 0) view.positionViewAtIndex(index, mode) }
    function positionViewAtBeginning() { if (view) view.positionViewAtBeginning() }
  }
  // A provider view (Codex, the device menus, a community view): the content
  // loads sourceComponent and reports the item back.
  QtObject {
    id: providerView
    property Component sourceComponent: null
    property var item: null
  }
  readonly property var searchProxy: search
  readonly property var listProxy: resultList
  readonly property var viewProxy: providerView
  readonly property var results: resultModel
  readonly property var levelTransform: levelShift
  // The content showing the palette, and its root item (the pointer gate
  // measures moves in it).
  property Item attachedView: null
  // Which host shows it: "island" (the island's launcher state), "panel"
  // (Launcher.qml's free panel) or "" (headless). Set by Launcher.qml.
  property string hostKind: ""
  readonly property Item viewItem: attachedView
  function attach(view, field, list) {
    if (root.attachedView && root.attachedView !== view && typeof root.attachedView.detached === "function") root.attachedView.detached()
    root.attachedView = view
    search.field = field
    resultList.view = list
    pointerGate.reset()
    resultList.sync(root.selected)
  }
  function detach(view) {
    if (root.attachedView !== view) return
    root.attachedView = null
    search.field = null
    resultList.view = null
    providerView.item = null
  }
  // The field's own edit (typing, paste, IME commit), after the view copied
  // its text here: typing supersedes speech and a pending clipboard transfer.
  function typed(text) {
    search.text = String(text)
    clipboardTransfer.cancel()
    root.voiceCancel()
    root.edited()
  }
  // The visible rows' title highlight (core/Match.js ranges()), as JSON pairs.
  property string matchQuery: ""
  function rangesFor(row) {
    if (!root.matchQuery || row.tier === "answer") return "[]"
    return JSON.stringify(Match.ranges(root.matchQuery, row.title))
  }
  // For the Colors answer: the bg its contrast row measures against, and the
  // pack its caption names a colour from.
  readonly property string contrastBackground: Tokens.hex(Tokens.bg)
  readonly property var themePalette: Theme.palette
  readonly property string themeName: Theme.name
}
