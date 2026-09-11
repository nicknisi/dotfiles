import QtQuick
import "../core/Match.js" as Match

Item {
  property var host: null
  readonly property var provider: ({
    apiVersion: 1,
    id: "dictation",
    name: "Dictate to Clipboard",
    icon: "󰍬",
    description: "Speak, copy, or paste into your previous window",
    settings: [],
    query: function(ctx) {
      if (ctx.scope && ctx.scope !== "dictation") return []
      if (!ctx.scope) {
        var score = ctx.query ? Match.match(ctx.query, "Dictate to Clipboard", "dictation speech voice transcribe paste microphone") : 23
        var rows = score ? [{ id: "open", title: "Dictate to Clipboard", subtitle: "Speak · Enter copies · Ctrl+Enter pastes", icon: "󰍬",
          score: score, order: 5, verb: "Dictate", remember: true, action: { type: "dictate" } }] : []
        // Search may normalize a spoken command; copy the original prose.
        var raw = String(ctx.rawQuery === undefined ? ctx.query || "" : ctx.rawQuery)
        if (raw.trim()) rows.push({ id: "copy-query", title: "Copy to Clipboard", subtitle: "Enter copies · Ctrl+Enter copies and pastes", icon: "󰅌",
          section: "Continue with", tier: "fallback", score: 1, verb: "Copy", preview: raw, previewLabel: "DICTATION",
          previewDetail: "Original text · Ctrl+Enter pastes into your previous window",
          action: { type: "dictation-copy", text: raw }, altAction: { type: "dictation-copy", text: raw, paste: true } })
        return rows
      }
      var text = String(ctx.query || "")
      return [{ id: "transcript", title: text ? "Copy dictated text" : "Start speaking…", subtitle: "Enter copies and closes · Ctrl+Enter pastes into your previous window",
        icon: "󰍬", score: 100, verb: "Copy", disabled: !text.trim(),
        preview: text, previewLabel: "DICTATION", previewDetail: "Full transcript · earlier words can change as you speak",
        action: { type: "dictation-copy", text: text }, altAction: { type: "dictation-copy", text: text, paste: true } }]
    }
  })
}
