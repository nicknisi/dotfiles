import QtQuick
import Quickshell
import Quickshell.Io
import "../../ClipboardModel.js" as ClipboardModel
import "../core/Match.js" as Match

// ClipboardPicker owns capture. This provider only reads its cliphist history,
// and only while inside Clipboard. No history is catalogued for global search.
Item {
  id: root
  property var host: null
  property var entries: []
  property var pendingEntries: []
  property bool loaded: false
  property var previewResult: ({})
  readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../helpers/clipboard-preview.lua").toString().replace(/^file:\/\//, ""))
  readonly property string mediaCache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard-media"
  readonly property bool scoped: !!host && host.opened && host.scope === "clipboard"

  readonly property var provider: ({
    apiVersion: 1, id: "clipboard", name: "Clipboard History", icon: "󰅌", color: "#8dbaec",
    description: "Text, images and video from the existing cliphist history",
    settings: [{ key: "limit", type: "number", label: "Maximum entries", "default": 100, min: 1, max: 300, integer: true }],
    query: function(ctx) { return root.query(ctx) },
    catalog: function(ctx) { return [root.navRow(26)] },
    opened: function() { if (root.scoped) root.refresh() }
  })

  function navRow(score) {
    return { id: "clipboard", title: "Clipboard History", subtitle: "Text, images and video", icon: "󰅌", section: "Clipboard",
      verb: "Open", tier: "item", score: score, order: 2, action: { type: "navigate", scope: "clipboard", title: "Clipboard" } }
  }
  function cleanup(image) {
    if (image) Quickshell.execDetached(["luajit", root.helperPath, "cleanup", image])
  }
  function clearPreview() {
    root.cleanup(root.previewResult.image)
    root.previewResult = ({})
  }
  onScopedChanged: {
    if (root.scoped) root.refresh()
    else { root.entries = []; root.loaded = false; root.clearPreview() }
  }
  function refresh() {
    if (!root.scoped || loader.running) return
    root.pendingEntries = []
    loader.running = true
  }
  Process {
    id: loader
    command: ["clipboard-list"]
    stdout: SplitParser {
      onRead: function(line) {
        if (!root.scoped || root.pendingEntries.length >= 300) return
        var tab = line.indexOf("\t"), id = line.slice(0, tab)
        if (tab <= 0 || !/^[0-9]{1,20}$/.test(id)) return
        root.pendingEntries.push(ClipboardModel.entry(id, line.slice(tab + 1, tab + 4001)))
      }
    }
    onExited: {
      root.entries = root.scoped ? root.pendingEntries : []
      root.pendingEntries = []
      root.loaded = root.scoped
      if (root.host) root.host.requery({ catalog: false, provider: "clipboard" })
    }
  }
  Connections {
    target: root.host
    ignoreUnknownSignals: true
    function onCurrentChanged() { root.loadPreview() }
  }
  function loadPreview() {
    if (!root.scoped || previewer.running) return
    var row = root.host.current
    if (!row || row.providerKey !== "clipboard" || !row.clipboardId || root.previewResult.id === row.clipboardId) return
    if (row.clipboardKind !== "text" && row.clipboardKind !== "image") { root.clearPreview(); return }
    root.clearPreview()
    previewer.requestId = row.clipboardId
    previewer.command = ["luajit", root.helperPath, "preview", row.clipboardId, row.clipboardKind]
    previewer.running = true
  }
  Process {
    id: previewer
    property string requestId: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var result
        try { result = JSON.parse(text) } catch (e) { return }
        if (!root.scoped || !root.host.current || root.host.current.clipboardId !== result.id) { root.cleanup(result.image); return }
        root.previewResult = result
        root.host.requery({ catalog: false, provider: "clipboard" })
      }
    }
    onExited: {
      if (root.scoped && root.host.current && root.host.current.clipboardId === previewer.requestId && root.previewResult.id !== previewer.requestId) {
        root.previewResult = { id: previewer.requestId, error: "Preview unavailable" }
        root.host.requery({ catalog: false, provider: "clipboard" })
      }
      Qt.callLater(function() { root.loadPreview() })
    }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "clipboard") return []
    if (!ctx.scope) {
      var s = ctx.query ? Match.match(ctx.query, "Clipboard History", "paste copied text images video") : 26
      return s ? [root.navRow(s)] : []
    }
    if (!root.loaded) { root.refresh(); if (ctx.pending) ctx.pending() }
    var rows = [], settings = ctx.settings || {}, limit = Math.max(1, Math.min(300, Number(settings.limit) || 100))
    for (var i = 0; i < root.entries.length && rows.length < limit; i++) {
      var entry = root.entries[i], text = entry.kind === "text"
      var title = text ? entry.preview.replace(/\s+/g, " ").slice(0, 120) : entry.kind.charAt(0).toUpperCase() + entry.kind.slice(1) + " · Clipboard"
      var score = Match.match(ctx.query, title, entry.kind, "", entry.preview)
      if (!score) continue
      var detail = root.previewResult.id === entry.id ? root.previewResult : {}
      var path = text ? "" : root.mediaCache + "/" + entry.id + "." + entry.extension
      rows.push({
        id: entry.id, clipboardId: entry.id, clipboardKind: entry.kind,
        title: title, subtitle: text ? "Text" : entry.preview, icon: "󰅌", section: "Clipboard", verb: "Copy",
        tier: "item", score: score, order: i, remember: false, hint: "Ctrl+Enter paste",
        action: { type: "exec", argv: ["luajit", root.helperPath, "copy", entry.id, entry.mime || "text"] },
        altAction: { type: "exec", argv: ["clipboard-paste", entry.id, entry.mime, path] },
        preview: detail.text !== undefined ? detail.text : (detail.error || entry.preview),
        previewImage: detail.image || "", previewLabel: "CLIPBOARD",
        previewDetail: (detail.truncated ? "Preview truncated · " : "") + "Enter copies · Ctrl+Enter pastes · Never included in global search"
      })
    }
    Qt.callLater(function() { root.loadPreview() })
    return rows
  }
}
