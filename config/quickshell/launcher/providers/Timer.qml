import QtQuick
import QtQuick as Quick
import Quickshell
import "../core/Match.js" as Match

// The registry owns this resident object, not the palette's view Loader.
// Deadlines use wall time so closing the palette or suspending does not pause it.
Item {
  id: root
  property var host: null
  property var timers: []
  property int nextId: 1
  property real now: Date.now()

  readonly property var provider: ({
    apiVersion: 1, id: "timer", name: "Timers", icon: "󰔛", color: "#e5c890",
    description: "Countdowns, for example timer 10m tea", settings: [],
    query: function(ctx) { return root.query(ctx) },
    catalog: function(ctx) { return [root.navRow(20)] },
    activate: function(row, ctx) { return root.activate(row) }
  })

  Quick.Timer {
    interval: 1000
    repeat: true
    running: root.timers.length > 0
    onTriggered: {
      root.now = Date.now()
      var expired = root.expire(root.now)
      for (var i = 0; i < expired.length; i++)
        Quickshell.execDetached(["notify-send", "--app-name=Launcher", "--", "Timer finished", expired[i].label])
      if (root.host && root.host.opened) root.host.requery({ catalog: false, provider: "timer" })
    }
  }
  function navRow(score) {
    return { id: "timers", title: "Timers", subtitle: "Start with timer 10m tea · " + root.timers.length + " running", icon: "󰔛",
      section: "Timers", tier: "item", verb: "Open", score: score, action: { type: "navigate", scope: "timer", title: "Timers" } }
  }
  function parse(input) {
    var text = String(input || "").trim().replace(/^timers?\b\s*/i, "")
    var total = 0, matched = false, token
    while ((token = /^(\d+(?:\.\d+)?)\s*(s(?:ec(?:ond)?s?)?|m(?:in(?:ute)?s?)?|h(?:ours?)?|d(?:ays?)?)(?=\s|\d|$)/i.exec(text))) {
      var unit = token[2].charAt(0).toLowerCase()
      total += Number(token[1]) * ({ s: 1000, m: 60000, h: 3600000, d: 86400000 })[unit]
      text = text.slice(token[0].length).trim()
      matched = true
    }
    if (!matched || !isFinite(total) || total < 1000 || total > 7 * 86400000) return null
    return { duration: Math.round(total), label: text.slice(0, 120) || "Timer" }
  }
  function remaining(timer, time) {
    var seconds = Math.max(0, Math.ceil((timer.deadline - time) / 1000))
    var hours = Math.floor(seconds / 3600), minutes = Math.floor(seconds % 3600 / 60)
    return (hours ? hours + ":" + (minutes < 10 ? "0" : "") : "") + minutes + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60
  }
  function start(duration, label, time) {
    if (!isFinite(duration) || duration < 1000 || duration > 7 * 86400000) return null
    var timer = { id: String(root.nextId++), label: String(label || "Timer").slice(0, 120), deadline: time + duration }
    root.timers = root.timers.concat([timer])
    root.now = time
    return timer
  }
  function stop(id) {
    root.timers = id === "all" ? [] : root.timers.filter(function(timer) { return timer.id !== id })
  }
  function expire(time) {
    var expired = root.timers.filter(function(timer) { return timer.deadline <= time })
    root.timers = root.timers.filter(function(timer) { return timer.deadline > time })
    return expired
  }
  function activate(row) {
    var action = row.action || {}
    if (action.type === "timer-start") {
      root.start(action.duration, action.label, Date.now())
      return { type: "close" }
    }
    if (action.type === "timer-stop") {
      root.stop(action.id)
      if (root.host) root.host.requery({ catalog: false, provider: "timer" })
      return { type: "noop" }
    }
    return action
  }
  function query(ctx) {
    if (ctx.scope && ctx.scope !== "timer") return []
    var query = String(ctx.query || "").trim(), scoped = ctx.scope === "timer", requested = /^timers?\b/i.test(query)
    if (!scoped && !requested) {
      var score = query ? Match.match(query, "Timers", "countdown alarm reminder") : 20
      return score ? [root.navRow(score)] : []
    }
    var text = query.replace(/^timers?\b\s*/i, ""), parsed = root.parse(text), rows = []
    if (parsed) rows.push({ id: "start", title: "Start timer: " + parsed.label, subtitle: root.remaining({ deadline: parsed.duration }, 0),
      icon: "󰔛", section: "Timers", tier: "answer", verb: "Start", score: 150, remember: false, intentFamily: "timer-start",
      action: { type: "timer-start", duration: parsed.duration, label: parsed.label } })
    var stop = /^(?:stop|cancel)\b\s*/i.test(text)
    var needle = stop ? text.replace(/^(?:stop|cancel)\b\s*/i, "") : /^(?:list|all)$/i.test(text) ? "" : text
    if (stop && (!needle || needle.toLowerCase() === "all") && root.timers.length)
      rows.push({ id: "stop-all", title: "Stop all timers", subtitle: root.timers.length + " running", icon: "󰔛", tier: "item", score: 100,
        verb: "Stop", intentFamily: "timer-stop", action: { type: "timer-stop", id: "all" } })
    for (var i = 0; !parsed && i < root.timers.length; i++) {
      var timer = root.timers[i]
      var score = !needle || needle.toLowerCase() === "all" || needle === timer.id ? 80 : Match.match(needle, timer.label)
      if (score) rows.push({ id: "timer-" + timer.id, title: timer.label, subtitle: root.remaining(timer, Date.now()) + " remaining · #" + timer.id,
        accessory: root.remaining(timer, Date.now()), icon: "󰔛", section: "Timers", tier: "item", score: score, order: i,
        verb: "Stop", hint: "Enter stops this timer", intentFamily: "timer-stop", action: { type: "timer-stop", id: timer.id } })
    }
    if (!rows.length) rows.push({ id: "help", title: "Start a countdown", subtitle: "timer 10m tea · timer 1h30m · timer list · timer stop", icon: "󰔛",
      tier: "answer", score: 1, disabled: true, action: { type: "noop" } })
    return rows
  }
}
