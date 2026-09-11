import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Units.js" as Units

// Units and temperatures in JS. Time zones go through helpers/timezone.lua,
// started once per distinct query after the regex gate matches, never per
// keystroke for anything else. Answers that move with the clock ("now in
// london") are refreshed every half minute while they are on screen.
Item {
  id: root
  property var host: null
  property string systemZone: ""
  property var timeCache: ({})
  property string inflight: ""
  property string queued: ""
  property bool liveShown: false
  readonly property int liveMaxAge: 30000
  readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../helpers/timezone.lua").toString().replace(/^file:\/\//, ""))

  readonly property var provider: ({
    apiVersion: 1,
    id: "converter",
    name: "Converter",
    icon: "\udb82\udfcd",
    color: "#81c8b6",
    description: "Units and daylight-saving aware time zones",
    settings: [{ key: "timezone", type: "string", label: "Your time zone", "default": "",
                 description: "IANA name such as Europe/Tallinn. Empty uses the system zone." }],
    query: function(ctx) { return root.query(ctx) }
  })

  Process {
    id: zoneProbe
    command: ["sh", "-c", "timedatectl show -p Timezone --value 2>/dev/null || readlink /etc/localtime | sed 's|.*/zoneinfo/||'"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.systemZone = text.trim() }
  }

  Process {
    id: helper
    property string forQuery: ""
    property string forZone: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var result
        try { result = JSON.parse(text) } catch (e) { result = { error: "Time-zone helper failed" } }
        result.cachedAt = Date.now()
        var cache = ({})
        for (var k in root.timeCache) cache[k] = root.timeCache[k]
        cache[helper.forQuery + "\n" + helper.forZone] = result
        root.timeCache = cache
      }
    }
    onExited: {
      root.inflight = ""
      if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
      if (root.queued) { var next = root.queued; root.queued = ""; root.startHelper(next.split("\n")[0], next.split("\n")[1]) }
    }
  }

  Timer { id: helperTimeout; interval: 1000; onTriggered: if (helper.running) helper.signal(9) }
  Timer { id: liveRefresh; interval: root.liveMaxAge; repeat: true; running: root.liveShown && root.host !== null; onTriggered: root.host.requery({ catalog: false, provider: root.provider.id }) }

  function startHelper(q, zone) {
    var key = q + "\n" + zone
    if (helper.running) { root.queued = key; return }
    root.inflight = key
    helper.forQuery = q
    helper.forZone = zone
    helper.command = ["luajit", root.helperPath, q, zone]
    helper.running = true
    helperTimeout.restart()
  }

  function navRow(score) {
    return { id: "converter", title: "Convert Anything", subtitle: "Units, temperatures & time zones", icon: "\udb82\udfcd", section: "Converter",
             verb: "Open", tier: "item", score: score, order: 4, action: { type: "navigate", scope: "converter", title: "Converter" } }
  }

  function answer(text, detail, query) {
    return { id: "conversion", title: text, subtitle: detail, icon: "\udb82\udfcd", section: "Converter", verb: "Copy result", tier: "answer", score: 195,
             action: { type: "copy", text: text }, preview: text, previewLabel: "CONVERSION", previewDetail: query + "\n" + detail }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "converter") return []
    if (!ctx.query) return ctx.scope ? [] : [navRow(23)]
    var rows = []
    if (!ctx.scope) {
      var s = Match.match(ctx.query, "Convert Anything", "converter units timezone temperature")
      if (s) rows.push(navRow(s))
    }
    var q = ctx.query.trim()
    try {
      var c = Units.convert(q)
      rows.unshift(root.answer(Units.formatValue(c.value) + " " + c.unit, Units.detailFor(c.unit), q))
      return rows
    } catch (e) { }
    root.liveShown = false
    if (!Units.isTimeQuery(q)) return rows
    var zone = ctx.settings.timezone || root.systemZone || "UTC"
    var key = q.toLowerCase() + "\n" + zone
    var cached = root.timeCache[key]
    var stale = !!cached && !!cached.live && Date.now() - cached.cachedAt > root.liveMaxAge
    if (!cached || stale) {
      if (root.inflight !== key && root.queued !== key) root.startHelper(q.toLowerCase(), zone)
      if (!cached) { ctx.pending(); return rows }
    }
    if (cached.error) {
      // Only messages the user can act on become rows; anything else is a
      // half-typed query and stays silent.
      if (cached.hint)
        rows.unshift({ id: "time-hint", title: cached.error.indexOf("daylight-saving") >= 0 ? "Ambiguous local time" : "Which time zone?",
                       subtitle: cached.error, icon: "◷", section: "Converter", verb: "", tier: "answer", score: 180, disabled: true,
                       action: { type: "noop" } })
      return rows
    }
    root.liveShown = !!cached.live
    rows.unshift(root.answer(cached.result, cached.detail, q))
    return rows
  }
}
