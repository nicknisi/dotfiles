import QtQuick
import Quickshell
import Quickshell.Io
import "../codex"
import "../codex/Policy.js" as Policy
import "../core/Match.js" as Match

Item {
  id: root
  property var host: null
  property var available: ({})
  readonly property var preferences: host ? host.settingsFor({key: "codex", provider: provider}) : ({})
  readonly property bool active: host ? host.providerEnabled({key: "codex", source: "bundled"}) : false
  readonly property alias session: session
  readonly property Component view: Component { ConversationView { session: root.session } }
  readonly property var provider: ({
    apiVersion: 1, id: "codex", name: "Codex", icon: "✳", description: "Ask here, follow up, or continue a task in Codex",
    settings: [
      {key: "model", type: "string", label: "Model", "default": "", description: "Empty uses Codex's current default. An override must be available in your Codex subscription."},
      {key: "fast", type: "boolean", label: "Fast mode", "default": true, description: "Uses more subscription allowance for priority processing"},
      {key: "destination", type: "enum", label: "Continue tasks in", "default": "desktop", options: ["desktop", "cli"]},
      {key: "workspace", type: "string", label: "Task working folder", "default": "", description: "Absolute folder for file and project tasks; desktop settings use ~/.config"}
    ],
    view: root.view,
    query: ctx => root.query(ctx),
    activate: (row, ctx) => root.activate(row, ctx),
    opened: function() { if (root.active) session.warm() },
    dismiss: function() { session.dismiss() }
  })
  CodexSession {
    id: session
    host: root.host
    settings: root.preferences
    onChanged: if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
    onHandoffReady: id => root.launch(id, "", session.cwd)
  }
  Process {
    id: detect
    command: ["sh", "-c", "for c in chatgpt codex; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done"]
    running: true
    stdout: StdioCollector { onStreamFinished: { var a = {}; text.trim().split("\n").forEach(x => a[x] = true); root.available = a } }
  }
  Connections { target: DesktopEntries.applications; function onValuesChanged() { if (!detect.running) detect.running = true } }
  onActiveChanged: if (!active) { session.shutdown(); if (host && host.activeProviderKey === "codex") host.closeProviderView() }
  function preferredScore() {
    var entry = host ? host.registryEntry("ai") : null
    return entry && host.settingsFor(entry).provider === "claude" ? 2.5 : 5
  }
  function raw(ctx) { return String(ctx.rawQuery === undefined ? ctx.query || "" : ctx.rawQuery).replace(/^\?\s*/, "") }
  function query(ctx) {
    if (ctx.scope && ctx.scope !== "codex") return []
    var text = raw(ctx), rows = [], scoped = ctx.scope === "codex"
    if (text.trim()) {
      rows.push({id: "ask", title: "Ask Codex here", subtitle: text, icon: "✳", section: "Continue with", tier: /^\?/.test(ctx.query) ? "answer" : "fallback", score: root.preferredScore(), verb: "Ask", hint: "Ctrl+Enter opens a task in Codex", action: {type: "provider-view", provider: "codex", text: text}, altAction: {type: "codex-external", text: text}})
      rows.push({id: "task", title: "Open task in Codex", subtitle: (root.preferences.destination === "cli" ? "Terminal" : "Desktop") + " · full request ready to continue", icon: "↗", section: "Continue with", tier: "fallback", score: root.preferredScore() - 0.1, verb: "Open", action: {type: "codex-external", text: text}})
      if (scoped) rows.push({id: "desktop-task", title: "Do this here · desktop settings", subtitle: "Explicit agent mode · may edit ~/.config · asks for additional access", icon: "⌘", score: 3, verb: "Start task", action: {type: "provider-view", provider: "codex", text: text, cwd: root.host.home + "/.config"}})
      if (scoped && root.preferences.workspace) rows.push({id: "project-task", title: "Do this here · working folder", subtitle: root.preferences.workspace, icon: "⌘", score: 2, verb: "Start task", action: {type: "provider-view", provider: "codex", text: text, cwd: root.preferences.workspace}})
    }
    if (!text.trim()) {
      if (!scoped) rows.push({id: "open", title: "Codex", subtitle: "Quick questions, recent conversations and tasks", icon: "✳", score: 24, verb: "Open", action: {type: "navigate", scope: "codex", title: "Codex"}})
      rows.push({id: "new", title: "Ask Codex here", subtitle: "Type or speak a quick question", icon: "✳", score: scoped ? 100 : 23, verb: "Ask", action: {type: "provider-view", provider: "codex", text: ""}})
    }
    var recent = session.recent
    for (var i = 0; i < Math.min(recent.length, scoped ? 40 : (text.trim() ? 0 : 1)); i++) {
      var row = recent[i], score = text.trim() ? Match.match(text, row.title) : 20 - i
      if (score) rows.push({id: "recent/" + row.id, title: scoped ? row.title : "Resume last question", subtitle: scoped ? new Date(row.updated).toLocaleString() : row.title,
        icon: "↶", section: "Recent questions", score: score, verb: "Resume", action: {type: "provider-view", provider: "codex", recent: row}})
    }
    return rows
  }
  function activate(row, ctx) {
    var effect = ctx.alternate && row.altAction ? row.altAction : row.action
    if (effect.type === "codex-external") { launch("", effect.text, preferences.workspace); return {type: "noop"} }
    if (effect.type === "provider-view") {
      if (effect.cwd && effect.cwd.charAt(0) !== "/") { host.errorMessage = "Choose an absolute working folder in Codex settings"; return {type: "noop"} }
      var success = effect.recent ? session.openRecent(effect.recent) : session.newQuestion(effect.text, effect.cwd)
      if (!success) { host.errorMessage = session.error; return {type: "noop"} }
      session.visible = true
    }
    return effect
  }
  function launch(id, text, cwd) {
    if ((id && !Policy.safeId(id)) || (cwd && cwd.charAt(0) !== "/")) { host.errorMessage = "Choose an absolute working folder and a valid conversation"; return }
    var argv, desktop = preferences.destination !== "cli" && available.chatgpt
    if (desktop) {
      var url = id ? Policy.externalUrl(id) : "codex://threads/new?prompt=" + encodeURIComponent(String(text || "")) + (cwd ? "&path=" + encodeURIComponent(cwd) : "")
      argv = ["chatgpt", url]
    } else if (available.codex) {
      argv = Policy.cliArgv(id, text, cwd)
    } else { session.error = "Codex is not installed. Your question is still here."; host.errorMessage = session.error; return }
    // Keep the full request. argv transport has an OS limit, not a hidden text cap.
    if (argv.some(x => String(x).length > 100000)) { session.error = "This request is too long for an app launch. Ask here, then continue the saved conversation."; host.errorMessage = session.error; return }
    host.cancel()
    Quickshell.execDetached(argv)
  }
}
