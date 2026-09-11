import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Emoji.js" as Emoji

Item {
  id: root
  property var host: null
  property var emojis: []
  readonly property string dataPath: decodeURIComponent(Qt.resolvedUrl("../assets/emojis.json").toString().replace(/^file:\/\//, ""))

  readonly property var provider: ({
    apiVersion: 1,
    id: "emoji",
    name: "Emoji Picker",
    icon: "☺",
    color: "#e8c575",
    description: "Search by name, or type : followed by a feeling",
    prefix: ":",
    settings: [],
    query: function(ctx) { return root.query(ctx) }
  })

  FileView {
    path: root.dataPath
    printErrors: false
    onLoaded: {
      try { root.emojis = JSON.parse(text()) } catch (e) { root.emojis = [] }
      if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
    }
  }

  function navRow(score, subtitle) {
    return { id: "emoji", title: "Emoji Picker", subtitle: subtitle, icon: "☺", section: "Emoji", verb: "Open", tier: "item",
             score: score, order: 5, action: { type: "navigate", scope: "emoji", title: "Emoji" } }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "emoji") return []
    if (!ctx.scope && !ctx.query) return [navRow(22, "Find the right feeling")]
    var prefixed = ctx.query.charAt(0) === ":"
    if (!ctx.scope && !prefixed) {
      var s = Match.match(ctx.query, "Emoji Picker", "smile emoticon")
      return s ? [navRow(s, "Type : followed by a feeling")] : []
    }
    var q = prefixed ? ctx.query.slice(1).trim() : ctx.query.trim()
    var found = Emoji.search(root.emojis, q, 80)
    var rows = []
    for (var i = 0; i < found.length; i++) {
      var f = found[i]
      rows.push({ id: String(f.index), title: Emoji.title(f.k), subtitle: f.e, icon: f.e, iconFont: "Noto Color Emoji", emoji: true,
                  section: "Emoji", verb: "Copy emoji", tier: "item", score: f.score, order: f.index,
                  action: { type: "copy", text: f.e }, preview: f.e, previewLabel: "EMOJI" })
    }
    return rows
  }
}
