import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Hotkeys.js" as Hotkeys

// Live keybindings with explicitly registered, generation-checked callbacks.
Item {
  id: root
  property var host: null
  property var binds: []
  property bool loaded: false
  property real loadedAt: 0
  readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../helpers/hotkeys.lua").toString().replace(/^file:\/\//, ""))

  readonly property var provider: ({
    apiVersion: 1,
    id: "hotkeys",
    name: "Hotkeys",
    icon: "",
    color: "#c4a7e7",
    description: "Live Hyprland keybindings and registered config actions",
    settings: [
      { key: "limit", type: "number", label: "Results at the root", "default": 10, min: 1, max: 50, integer: true,
        description: "The Hotkeys screen lists every bind; this caps what mixes into the global search." },
      { key: "keyboardOnly", type: "boolean", label: "Show keyboard-only binds", "default": true,
        description: "Opaque Lua callbacks and unsupported dispatchers appear disabled so their keys can be learned." }
    ],
    query: function(ctx) { return root.query(ctx) },
    catalog: function(ctx) { return root.catalog(ctx) },
    activate: function(row, ctx) { return root.activate(row) },
    opened: function() { root.refresh(false) }
  })

  // Refresh at most once per 30 seconds, never on every keystroke.
  function refresh(force) {
    if (loader.running) return
    if (!force && root.loaded && Date.now() - root.loadedAt < 30000) return
    loader.command = Hotkeys.loadArgv(root.helperPath)
    loader.running = true
  }

  Process {
    id: loader
    stdout: StdioCollector {
      onStreamFinished: {
        // Empty results and failed helpers both clear stale binds.
        root.binds = Hotkeys.parse(text)
      }
    }
    onExited: {
      root.loaded = true
      root.loadedAt = Date.now()
      if (root.host) root.host.requery({ provider: root.provider.id })
    }
  }

  function activate(row) {
    if (!row.action || row.action.type !== "hotkey") return row.action
    var argv = Hotkeys.dispatchArgv(row.action)
    return argv.length ? { type: "exec", argv: argv } : { type: "noop" }
  }

  function catalog(ctx) {
    var rows = []
    for (var i = 0; i < root.binds.length; i++) {
      var bind = root.binds[i]
      if (!Hotkeys.runnable(bind)) continue
      var row = Hotkeys.row(bind, 1)
      row.keywords = Hotkeys.keywords(bind)
      row.descriptionKey = bind.registration ? bind.registration.generation + "\u001f" + bind.registration.id : bind.dispatcher + "\u001f" + bind.arg
      rows.push(row)
    }
    return rows
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "hotkeys") return []
    var rows = []
    if (!ctx.scope) {
      if (!ctx.query) return [Hotkeys.navRow(18)]
      var s = Match.match(ctx.query, "Hotkeys", "keybindings keys shortcuts bindings hyprland")
      if (s) rows.push(Hotkeys.navRow(s))
    }
    if (!root.loaded) { root.refresh(true); if (ctx.pending) ctx.pending(); return rows }
    return rows.concat(Hotkeys.rows(ctx.query, root.binds, ctx.settings, !!ctx.scope))
  }
}
