import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core/Match.js" as Match

// Open windows: switch to one, or close it with Ctrl+Enter. Alt+Tab opens
// this screen directly (config/hypr/hyprland.lua).
//
// The list comes from wlr-foreign-toplevel (ToplevelManager), which is what
// gives activate() and close(). Hyprland's own toplevel list is matched to it
// for the workspace name and the focus order, which the Wayland protocol does
// not carry. Rows are not bindable to hotkeys: a window has no stable identity
// across sessions, so there is no catalog.
Item {
  id: root
  property var host: null

  readonly property var provider: ({
    apiVersion: 1,
    id: "windows",
    name: "Windows",
    icon: "󰖯",
    color: "#8fbcbb",
    description: "Switch to an open window, or close one",
    settings: [],
    query: function(ctx) { return root.query(ctx) },
    activate: function(row, ctx) { return root.activate(row, ctx) }
  })

  // Windows come and go while the palette is open, and the focus order moves
  // with every switch; ask for a requery rather than showing a stale list.
  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.refresh() }
  }
  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.refresh() }
  }
  function refresh() { if (root.host && root.host.opened) root.host.requery({ provider: root.provider.id }) }

  function hyprFor(toplevel) {
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) if (list[i].wayland === toplevel) return list[i]
    return null
  }

  // Most recently focused first, with the focused window itself last: on a
  // fresh screen the first row is the window you came from, so Enter swaps.
  function entries() {
    var out = [], list = ToplevelManager.toplevels.values
    for (var i = 0; i < list.length; i++) {
      var t = list[i], h = root.hyprFor(t)
      var ipc = h && h.lastIpcObject ? h.lastIpcObject : {}
      out.push({ toplevel: t, hypr: h, recency: typeof ipc.focusHistoryID === "number" ? ipc.focusHistoryID : 1000 + i })
    }
    out.sort(function(a, b) {
      if (a.toplevel.activated !== b.toplevel.activated) return a.toplevel.activated ? 1 : -1
      return a.recency - b.recency
    })
    return out
  }

  function rowFor(e, score, order) {
    var t = e.toplevel, appId = String(t.appId || ""), title = String(t.title || appId || "Window")
    var entry = appId ? DesktopEntries.heuristicLookup(appId) : null
    var app = entry ? String(entry.name || appId) : appId
    var where = e.hypr && e.hypr.workspace ? "Workspace " + e.hypr.workspace.name : ""
    return {
      id: e.hypr && e.hypr.address ? e.hypr.address : Qt.md5(appId + "\n" + title),
      title: title, subtitle: [app, where].filter(Boolean).join(" · "), keywords: app,
      icon: "󰖯", iconSource: entry && root.host && root.host.appLibrary ? root.host.appLibrary.iconSource(entry.icon) : "",
      section: "Windows", verb: "Focus", tier: "item", score: score, order: order,
      accessory: t.activated ? "Current" : "", hint: "Ctrl+↵ close",
      toplevel: t, action: { type: "window-focus" }, altAction: { type: "window-close" },
      description: appId, descriptionKey: app
    }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "windows") return []
    var all = root.entries()
    if (!ctx.scope && !ctx.query)
      return [{ id: "windows", title: "Windows", subtitle: all.length === 1 ? "1 open window" : all.length + " open windows",
                icon: "󰖯", section: "Windows", verb: "Open", tier: "item", score: 26, order: 0,
                action: { type: "navigate", scope: "windows", title: "Windows" } }]
    var rows = []
    for (var i = 0; i < all.length; i++) {
      var e = all[i]
      if (!ctx.query) { rows.push(root.rowFor(e, 1, i)); continue }
      var t = e.toplevel, appId = String(t.appId || "")
      var entry = appId ? DesktopEntries.heuristicLookup(appId) : null
      var s = Match.match(ctx.query, String(t.title || appId), entry ? String(entry.name || "") : "", "", appId)
      // A window that matches well sits with the app rows, below an exact app hit.
      if (s) rows.push(root.rowFor(e, ctx.scope ? s : s + (s >= 78 ? 20 : 0), i))
    }
    return rows
  }

  // The palette drops its keyboard grab before the switch lands, so focus
  // settles on the chosen window rather than bouncing off the closing layer.
  function activate(row, ctx) {
    var t = row.toplevel
    if (!t) return { type: "close" }
    var closing = !!(ctx && ctx.alternate)
    Qt.callLater(function() { if (closing) t.close(); else t.activate() })
    return { type: "close" }
  }
}
