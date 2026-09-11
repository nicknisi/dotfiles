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
import "core/Intent.js" as Intent
import "core/Patterns.js" as Patterns
import "core/SmartMatch.js" as SmartMatch
import "core/Motion.js" as Motion
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
  // the scrim use cancel() and never start recording.
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
    { key: "accent", type: "enum", label: "Accent color", "default": "theme", options: ["theme", "ember", "violet", "mint"], description: "Theme follows the active shell theme" },
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
  property string fontFamily: Style.font.menuFamily
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
  readonly property var current: rows.length && selected >= 0 && selected < rows.length ? rows[selected] : ({})
  readonly property bool compact: paletteSettings.density !== "comfortable"
  readonly property color accent: paletteSettings.accent === "ember" ? "#ee987e" : paletteSettings.accent === "violet" ? "#b5a0ef" : paletteSettings.accent === "mint" ? "#8bceb4" : Color.accent
  readonly property bool clipboardChoice: root.dictationMode || !!(root.current.action && root.current.action.type === "dictation-copy")
  readonly property bool previewVisible: !dmenuActive && paletteSettings.showPreview !== false && !!(current.preview || current.previewImage || current.swatch)

  // ---------------------------------------------------------------- motion
  // Three tiers (core/Motion.js) drive every transition: the window's
  // reveal, a menu level entering, the selection gliding and the activated
  // row's flash. A duration of 0 turns a transition into a plain assignment.
  readonly property var motion: Motion.profile(paletteSettings.animations)
  readonly property bool windowSlides: paletteSettings.windowTransition === "slide"
  // The window transition is chosen apart from the tier: Instant keeps the
  // rest of the palette animated while the window itself appears at once.
  readonly property int windowDuration: paletteSettings.windowTransition === "instant" ? 0 : motion.window
  // 0 hidden … 1 shown; the scrim and the card follow it. The layer stays
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

  // Theme surfaces, same tokens as the stock menu.
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
  readonly property color hairline: Util.alpha(foreground, 0.12)
  readonly property color muted: Util.alpha(foreground, 0.55)

  // Type scale for provider views. A view covers the whole card, so it has to
  // carry the palette's own sizes -- including the density bump -- or it reads
  // a step smaller than the results it replaced. Ladder: fontInput is the
  // search field, fontTitle a row title, fontBody a preview body, fontLabel a
  // row subtitle or footer, fontCaption a keycap or the breadcrumb brand.
  readonly property int fontInput: compact ? Style.font.heading : Style.font.heading + 2
  readonly property int fontTitle: compact ? Style.font.title : Style.font.title + 1
  readonly property int fontBody: Style.font.body
  readonly property int fontLabel: Style.font.bodySmall
  readonly property int fontCaption: Style.font.caption
  // Tells a provider view it need not paint its own backdrop; an older
  // host leaves this undefined, so a view can still fall back.
  readonly property bool paintsViewBackdrop: true

  onPendingChanged: { if (pending) loadingDelay.restart(); else { loadingDelay.stop(); showLoading = false } }
  Timer { id: loadingDelay; interval: 180; onTriggered: root.showLoading = root.pending }
  Timer { id: debounce; interval: 25; onTriggered: root.runQuery() }

  Providers.Registry { id: providerRegistry; host: root }
  readonly property var registry: providerRegistry
  ListModel { id: resultModel }
  PointerMoveGate { id: pointerGate; referenceItem: card }

  // ---------------------------------------------------------------- opening
  function resetSelection() {
    root.selectionTouched = false
    root.selected = 0
    root.ctrlHeld = false
    pointerGate.reset()
  }

  function openRoute(input, payload) {
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
    if (root.dmenuActive) { root.applyRows(root.dmenuRows()); root.pending = false; root.afterRows(); return }
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
    root.applyRows(ranked.slice(0, 120))
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

  function display(row, index, previousSection) {
    return { uid: row.uid, title: row.title, subtitle: row.subtitle, icon: row.icon, iconFont: row.iconFont, iconSource: row.iconSource,
             tint: row.tint, section: row.section, sectionStart: row.section !== previousSection, verb: row.verb, accessory: row.accessory,
             disabled: row.disabled, badge: row.badge, answer: row.tier === "answer", hint: row.hint }
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
    if (resultList.currentIndex !== root.selected) resultList.currentIndex = root.selected
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

  function activateRow(row, alternate) {
    if (!row || row.disabled || root.confirmPending) return
    var entry = root.registryEntry(row.providerKey)
    if (!entry || !root.providerEnabled(entry)) return
    var action = alternate && row.altAction ? row.altAction : row.action
    var confirmation = alternate && row.altAction && row.altConfirm !== undefined ? String(row.altConfirm) : row.confirm
    // Voice binding installation owns its confirmation, including direct calls.
    if (action && action.type === "voice-bindings") { root.installVoiceBindings(); return }
    var run = function() {
      var currentEntry = root.registryEntry(row.providerKey)
      if (!currentEntry || currentEntry.provider !== entry.provider || !root.providerEnabled(currentEntry)) return
      var effect = action
      if (typeof currentEntry.provider.activate === "function") {
        try { effect = currentEntry.provider.activate(row, { host: root, settings: root.settingsFor(currentEntry), alternate: alternate === true, confirmed: !!confirmation }) || effect }
        catch (e) { root.errorMessage = currentEntry.provider.name + ": " + e; return }
      }
      if (!effect) return
      root.flash(row.uid)
      root.remember(row)
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
    return JSON.stringify({ opened: root.opened, mode: root.mode, view: root.activeProviderKey, scope: root.scope, query: search.text, count: root.rows.length,
      titles: root.rows.map(function(r) { return r.title }), selected: root.selected, pending: root.pending, patterns: root.lastPatterns,
      current: { uid: root.current.uid || "", icon: root.current.icon || "", iconSource: root.current.iconSource || "", badge: root.current.badge || "", tier: root.current.tier || "" },
      modelCount: resultModel.count, providers: providerRegistry.entries.map(function(e) { return e.key }), problems: providerRegistry.problems,
      applications: { library: !!root.appLibrary, entries: appEntries.length },
      matching: { mode: root.matchingSettings.mode, model: root.matchingSettings.model, loaded: matchingSession.loaded, status: matchingSession.status, error: matchingSession.error },
      error: root.errorMessage, configError: root.configError, status: root.statusMessage,
      voice: { backend: "voxtype", state: voice.phase, trigger: root.voiceTrigger, enabled: root.voiceEnabled, detected: voice.detected, version: voice.version,
               command: voice.command, daemon: voice.daemonState, bindings: root.voiceBindingsStatus, frames: voice.history.length, live: voice.liveText } })
  }

  // ------------------------------------------------------------------ view
  readonly property int headerHeight: Style.space(compact ? 66 : 78)
  readonly property int crumbHeight: Style.space(30)
  readonly property int footerHeight: Style.space(46)
  readonly property int rowHeight: Style.space(compact ? 46 : 56)
  readonly property int rowSpacing: Style.space(3)
  readonly property int dmenuRowsHeight: {
    var count = Math.max(1, resultModel.count)
    var maxRows = root.dmenuMaxHeight > 0 ? Math.max(1, Math.floor(Style.space(root.dmenuMaxHeight) / (rowHeight + rowSpacing))) : 12
    return Math.min(count, maxRows) * (rowHeight + rowSpacing)
  }

  PanelWindow {
    id: panel
    visible: root.opened || root.closing
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // A launch must find the keyboard free at once, however long the fade-out runs.
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: root.scrim; opacity: root.reveal; MouseArea { anchors.fill: parent; onClicked: root.cancel() } }

    SurfaceShadow { surface: card }

    BorderSurface {
      id: card
      width: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : Style.space(root.compact ? 640 : 760), panel.width - Style.gapsOut * 2)
      height: root.dmenuActive
        ? Math.min(root.headerHeight + (root.mode === "input" ? Style.space(12) : root.dmenuRowsHeight + Style.space(20)), panel.height - Style.gapsOut * 2)
        : Math.min(Style.space(root.compact ? 540 : 580), panel.height - Style.gapsOut * 2)
      anchors.horizontalCenter: parent.horizontalCenter
      y: (root.dmenuActive ? Math.max(Style.gapsOut, Math.round((panel.height - height) / 2)) : Math.max(Style.gapsOut, Math.round((panel.height - height) * 0.38)))
         + (root.windowSlides ? Math.round((1 - root.reveal) * Style.space(Motion.WINDOW_SLIDE_PX)) : 0)
      opacity: root.reveal
      radius: Theme.panelRadius
      color: root.background
      borderSpec: root.borderSpec
      clip: true
      Accessible.role: Accessible.Dialog
      Accessible.name: "Launcher command palette"
      MouseArea { anchors.fill: parent; onClicked: {} }

      // A provider view covers the palette, so the host paints the backdrop
      // it needs and keeps both inside the card's border. Filling the card
      // outright would paint over the border ring, which BorderSurface draws
      // as the surface itself (or as an overlay child below this z).
      Rectangle {
        id: viewBackdrop
        visible: !!providerView.item
        z: 4
        anchors.fill: parent
        anchors.topMargin: card.borderTop; anchors.rightMargin: card.borderRight
        anchors.bottomMargin: card.borderBottom; anchors.leftMargin: card.borderLeft
        radius: Math.max(0, card.radius - Math.max(card.borderTop, card.borderLeft))
        color: root.background
      }

      Loader {
        id: providerView
        anchors.fill: viewBackdrop
        z: 5
        transform: levelShift
        opacity: root.levelOpacity
        onLoaded: { item.host = root; Qt.callLater(root.focusInput) }
      }

      // Header: search field
      Item {
        id: header
        visible: !root.providerViewActive
        x: Style.space(root.compact ? 20 : 24); y: 0
        width: parent.width - x * 2
        height: root.headerHeight
        Item {
          id: glyph
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22); height: width
          Rectangle { visible: !voice.active; x: 1; y: 1; width: Style.space(15); height: width; radius: width / 2; color: "transparent"; border.color: root.accent; border.width: 1.8 }
          Rectangle { visible: !voice.active; x: Style.space(13); y: Style.space(13); width: Style.space(9); height: 1.8; radius: 0.9; rotation: 45; transformOrigin: Item.Left; color: root.accent }
          // Recording dot, swelling with the microphone.
          Rectangle {
            visible: voice.active
            anchors.centerIn: parent
            width: Style.space(10); height: width; radius: width / 2
            color: voice.phase === "listening" ? root.accent : Util.alpha(root.accent, 0.55)
            scale: voice.phase === "listening" ? 1 + 0.6 * voice.level : 1
            Behavior on scale { NumberAnimation { duration: 60 } }
          }
        }
        VoiceWave {
          id: wave
          visible: voice.active
          anchors.right: escCap.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          // Switching away from two horizontal anchors does not restore a
          // constant width. Keep one anchor and bind both widths explicitly.
          width: root.liveText ? Math.min(Style.space(96), fieldWidth * 0.22) : fieldWidth
          readonly property real fieldWidth: Math.max(0, escCap.x - Style.space(12) - glyph.x - glyph.width - Style.space(14))
          height: Style.space(40)
          mode: voice.phase
          level: voice.level
          history: voice.history
          accent: root.accent
          foreground: root.foreground
        }
        TextInput {
          id: search
          anchors.left: glyph.right
          anchors.leftMargin: Style.space(14)
          anchors.right: root.liveText ? wave.left : escCap.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(40)
          verticalAlignment: TextInput.AlignVCenter
          color: root.foreground
          selectionColor: Util.alpha(root.accent, 0.45)
          selectedTextColor: root.foreground
          font.family: root.fontFamily
          font.pixelSize: root.fontInput
          selectByMouse: true
          clip: true
          focus: true
          opacity: voice.active && !root.liveText ? 0 : 1   // the string takes the field until words arrive; focus and keys stay here
          Accessible.name: root.dmenuActive ? root.dmenuPrompt : "Search commands, apps and extensions"
          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.dictationMode ? "Speak or edit your dictation…" : root.dmenuActive ? root.dmenuPrompt + "…" : root.scope ? "Search " + root.scopeTitle.toLowerCase() + "…" : "What would you like to do?"
            textFormat: Text.PlainText
            color: Util.alpha(root.foreground, 0.42)
            font: parent.font
            visible: !parent.text && !parent.preeditText && !voice.active
            elide: Text.ElideRight
          }
          onTextEdited: { clipboardTransfer.cancel(); root.voiceCancel(); root.edited() }
          Keys.priority: Keys.BeforeItem
          Keys.onReleased: function(event) {
            // Hold mode ends when the modifier comes up (Hyprland swallows the
            // hotkey's own release, and its release bind only fires while the
            // modifier is still down). A tap's release must not end anything.
            if (voice.active && root.voiceTrigger === "hold" && root.isSuperKey(event.key)) { root.voiceStop(); event.accepted = true }
            if (event.key === Qt.Key_Control) root.ctrlHeld = false
          }
          Keys.onPressed: function(event) {
            // Ctrl's own press carries no modifier flag yet; a chord pressed
            // with Ctrl already down (before the palette opened) does.
            root.ctrlHeld = event.key === Qt.Key_Control || !!(event.modifiers & Qt.ControlModifier)
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.isAutoRepeat) { event.accepted = true; return }
            if (root.confirmPending) { confirmDialog.handleKey(event); event.accepted = true; return }
            if (voice.active) {
              if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true; return }
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.dictationMode) root.dictationAccept(!!(event.modifiers & Qt.ControlModifier))
                else root.voiceStop()
                event.accepted = true; return
              }
              if (root.isModifierKey(event.key)) { event.accepted = true; return }
              root.voiceCancel() // typing and navigation supersede speech immediately
            }
            var ctrl = event.modifiers & Qt.ControlModifier
            var atEnd = cursorPosition === text.length
            if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
            else if (ctrl && event.key === Qt.Key_U) { text = ""; root.edited(); event.accepted = true }
            else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) { root.select(1); event.accepted = true }
            else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) { root.select(-1); event.accepted = true }
            else if (event.key === Qt.Key_PageDown) { root.selectPage(6); event.accepted = true }
            else if (event.key === Qt.Key_PageUp) { root.selectPage(-6); event.accepted = true }
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { root.select(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true }
            else if (ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { root.activate(true); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(); event.accepted = true }
            else if (event.key === Qt.Key_Right && (atEnd || !text) && !root.dmenuActive && root.rows.length) { root.activate(); event.accepted = true }
            else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) && !text && !preeditText && (root.scope || root.history.length)) { root.goBack(); event.accepted = true }
            else if (event.key === Qt.Key_Delete && !text && root.current.appId) { root.requestUninstall(); event.accepted = true }
            else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_8) { root.activateAt(event.key - Qt.Key_1); event.accepted = true }
            else if (ctrl && event.key === Qt.Key_Comma && !root.dmenuActive) { root.navigate("settings", "Settings"); event.accepted = true }
            else if (ctrl && event.key === Qt.Key_K && !root.dmenuActive) {
              var key = root.current.providerKey && root.current.providerKey !== "settings" ? "settings/" + root.current.providerKey : "settings"
              root.navigate(key, root.current.providerName || "Settings")
              event.accepted = true
            }
          }
        }
        Keycap { id: escCap; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; label: "esc"; foreground: root.foreground }
      }
      Rectangle { x: 0; y: root.headerHeight; width: parent.width; height: 1; color: root.hairline }

      // Breadcrumb line (palette mode)
      Row {
        id: crumbs
        visible: !root.dmenuActive
        transform: levelShift
        opacity: root.levelOpacity
        x: Style.space(root.compact ? 22 : 26); y: root.headerHeight + Style.space(8)
        height: root.crumbHeight
        spacing: Style.space(10)
        Text { id: brand; anchors.verticalCenter: parent.verticalCenter; text: "LAUNCHER"; textFormat: Text.PlainText; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 2; font.weight: Font.Bold }
        Text { anchors.baseline: brand.baseline; text: root.scope ? "›" : "/"; textFormat: Text.PlainText; color: Util.alpha(root.foreground, 0.35); font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        Text {
          anchors.baseline: brand.baseline
          text: root.scope ? root.scopeTitle : search.text ? "Search results" : "Apps, commands, answers"
          textFormat: Text.PlainText
          color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
        }
      }

      // Results and preview
      Item {
        id: content
        transform: levelShift
        opacity: root.levelOpacity
        x: Style.space(12)
        y: root.dmenuActive ? root.headerHeight + Style.space(10) : root.headerHeight + root.crumbHeight + Style.space(10)
        width: parent.width - Style.space(24)
        height: parent.height - y - (root.dmenuActive ? Style.space(10) : root.footerHeight + Style.space(10))

        ListView {
          id: resultList
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: root.previewVisible ? Math.round(parent.width * 0.55) : parent.width
          model: resultModel
          clip: true
          spacing: root.rowSpacing
          boundsBehavior: Flickable.StopAtBounds
          cacheBuffer: root.rowHeight * 4
          // One highlight glides between rows instead of each row painting
          // its own; its geometry is bound here so it covers the row and not
          // the delegate's section header.
          highlightFollowsCurrentItem: false
          highlight: BorderSurface {
            readonly property var row: resultList.currentItem
            z: 0
            visible: !!row && root.rows.length > 0
            width: resultList.width
            height: row ? row.rowHeight : root.rowHeight
            y: row ? row.y + row.rowY : 0
            opacity: row && row.disabled ? 0.62 : 1
            radius: Style.cornerRadius
            color: root.selectedBackground
            borderSpec: root.selectedBorderSpec
            Behavior on y { enabled: root.selectionTouched && root.motion.selection > 0; NumberAnimation { duration: root.motion.selection; easing.type: Easing.OutCubic } }
          }
          delegate: Column {
            id: delegateRoot
            z: 1
            readonly property real rowY: rowItem.y
            readonly property real rowHeight: rowItem.height
            required property int index
            required property string uid
            required property string title
            required property string subtitle
            required property string icon
            required property string iconFont
            required property string iconSource
            required property string tint
            required property string section
            required property bool sectionStart
            required property string verb
            required property string accessory
            required property bool disabled
            required property string badge
            required property bool answer
            required property string hint
            width: resultList.width
            // The idle root lists one row per provider, so headers would label single items there;
            // they return as soon as a query or a scope groups real sets.
            readonly property bool showHeader: !root.dmenuActive && (!!root.scope || !!search.text) && sectionStart && !!section
            Item {
              width: parent.width
              height: delegateRoot.showHeader ? Style.space(root.compact ? 22 : 26) : 0
              visible: delegateRoot.showHeader
              Text {
                x: Style.space(14); anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(3)
                text: delegateRoot.section
                textFormat: Text.PlainText
                color: Util.alpha(root.foreground, 0.5)
                font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Medium; font.letterSpacing: 0.5
              }
            }
            ResultRow {
              id: rowItem
              width: parent.width
              paintsSelection: false
              flashRise: root.motion.flashRise; flashFall: root.motion.flashFall
              title: delegateRoot.title; subtitle: delegateRoot.subtitle; icon: delegateRoot.icon; iconFont: delegateRoot.iconFont
              iconSource: delegateRoot.iconSource; tint: delegateRoot.tint; verb: delegateRoot.verb; accessory: delegateRoot.accessory
              badge: delegateRoot.badge; hint: delegateRoot.hint; disabled: delegateRoot.disabled; answer: delegateRoot.answer
              shortcut: root.ctrlHeld && !root.dmenuActive && delegateRoot.index < root.shortcutRows ? String(delegateRoot.index + 1) : ""
              compact: root.compact
              selected: root.selected === delegateRoot.index
              accent: root.accent; foreground: root.foreground
              selectedBackground: root.selectedBackground; selectedText: root.selectedText; selectedBorderSpec: root.selectedBorderSpec
              onHovered: function(item, mouse) { root.selectFromPointer(delegateRoot.index, item, mouse) }
              onActivated: { root.selectionTouched = true; root.selected = delegateRoot.index; root.activate() }
              Connections { target: root; function onFlashed(uid) { if (uid === delegateRoot.uid) rowItem.flash() } }
            }
          }
        }
        Rectangle { visible: root.previewVisible; x: resultList.width + Style.space(12); width: 1; height: parent.height - Style.space(12); color: root.hairline }
        PreviewPane {
          visible: root.previewVisible
          x: resultList.width + Style.space(30)
          width: parent.width - x - Style.space(10)
          height: parent.height
          row: root.current
          compact: root.compact
          accent: root.accent
          foreground: root.foreground
        }
        Column {
          visible: root.rows.length === 0 && root.mode !== "input" && (!root.pending || root.showLoading)
          anchors.centerIn: parent
          spacing: Style.space(12)
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✳"; textFormat: Text.PlainText; color: root.accent; font.family: Style.font.iconFamily; font.pixelSize: Style.space(40) }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pending ? "Finding your next move…" : search.text ? "No matches for “" + search.text + "”" : root.scope === "clipboard" ? "Your clipboard is empty" : root.scope === "files" ? "Type to search your home folder" : "Nothing here yet"
            textFormat: Text.PlainText; color: root.foreground; opacity: 0.8; font.family: root.fontFamily; font.pixelSize: Style.font.title
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.scope === "converter" ? "Try 2m in feet or 10 am in London" : root.dmenuActive ? "" : "Search by name. Follow your curiosity."
            textFormat: Text.PlainText; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
        }
      }

      // Footer (palette mode)
      Rectangle { visible: !root.dmenuActive; x: 0; y: parent.height - root.footerHeight; width: parent.width; height: 1; color: root.hairline }
      Item {
        visible: !root.dmenuActive
        x: Style.space(22); y: parent.height - root.footerHeight; width: parent.width - Style.space(44); height: root.footerHeight
        Row {
          anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(8)
          Text {
            text: voice.phase === "listening" ? (root.voiceTrigger === "hold" ? "Listening… release to finish" : "Listening… tap the hotkey again or press ↵ to finish")
                : voice.phase === "transcribing" ? "Finishing transcript…" : voice.phase === "starting" ? "Starting voxtype…"
                : root.pending && root.showLoading ? "Searching…" : root.errorMessage ? "Needs attention: " + root.errorMessage : root.statusMessage || (root.current.providerName ? root.current.providerName : "Launcher")
            textFormat: Text.PlainText; elide: Text.ElideRight; width: Math.min(implicitWidth, card.width * 0.5)
            color: root.errorMessage ? Color.urgent : root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(8)
          Text { text: root.dictationMode ? "Copy" : voice.active ? "Finish" : root.current.verb || "Select"; textFormat: Text.PlainText; color: Util.alpha(root.foreground, 0.8); font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
          Keycap { label: "↵"; bright: true; foreground: root.foreground }
          Item { width: Style.space(8); height: 1 }
          Text { text: root.clipboardChoice ? "Paste" : root.compact ? "Settings" : "Provider settings"; textFormat: Text.PlainText; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; anchors.verticalCenter: parent.verticalCenter }
          Keycap { label: root.clipboardChoice ? "ctrl ↵" : "ctrl K"; foreground: root.foreground }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 10
        opened: root.confirmPending !== null
        message: root.confirmPending ? root.confirmPending.message : ""
        confirmText: root.confirmPending ? root.confirmPending.confirmText : "Confirm"
        background: root.background
        foreground: root.foreground
        scrim: root.scrim
        selectedBackground: root.selectedBackground
        selectedText: root.selectedText
        fontFamily: root.fontFamily
        cornerRadius: Style.cornerRadius
        onCanceled: { root.confirmPending = null; Qt.callLater(root.focusInput) }
        onConfirmed: { var run = root.confirmPending ? root.confirmPending.run : null; root.confirmPending = null; if (run) run(); Qt.callLater(root.focusInput) }
      }
    }
  }
}
