import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Match.js" as Match
import "../core/Files.js" as Files

// Files and folders under the home folder through `fd`, one bounded run per
// distinct query. The host debounces keystrokes; a query whose result is not
// cached yet returns nothing, marks the query pending and requeries when fd
// exits. A newer query kills a run that is still walking; the requery that
// follows starts whatever the palette wants by then. The cache lives for one
// summon so results reflect the disk as it was when the palette opened.
Item {
  id: root
  property var host: null
  property bool available: false
  property var cache: ({})
  property string inflight: ""
  property bool superseded: false
  readonly property string home: Quickshell.env("HOME")

  readonly property var provider: ({
    apiVersion: 1,
    id: "files",
    name: "Files",
    icon: "󰈞",
    color: "#e5c07b",
    description: "Files and folders under your home folder, found with fd",
    prefix: "~",
    settings: [
      { key: "searchMode", type: "enum", label: "Search in the main palette", "default": "fuzzy",
        options: ["fuzzy", "literal", "prefix"], optionLabels: ["Fuzzy", "Literal", "Only with ~"],
        description: "Type ~ for fuzzy file and folder search in any mode. Searches under your home folder." },
      { key: "files", type: "boolean", label: "Include files", "default": true },
      { key: "folders", type: "boolean", label: "Include folders", "default": true },
      { key: "hidden", type: "boolean", label: "Include hidden entries", "default": false,
        description: "Dotfiles and dot-folders such as ~/.config. Slower on a large home folder." },
      { key: "limit", type: "number", label: "Results at the root", "default": 10, min: 1, max: 50, integer: true,
        description: "The Files screen shows more; this caps what mixes into the global search." }
    ],
    query: function(ctx) { return root.query(ctx) },
    opened: function() { root.cache = ({}) }
  })

  Process {
    id: probe
    command: ["sh", "-c", "command -v fd"]
    running: true
    onExited: function(code) { root.available = code === 0 }
  }

  Process {
    id: fd
    property string forKey: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.superseded) return
        var next = ({})
        for (var k in root.cache) next[k] = root.cache[k]
        next[fd.forKey] = Files.parse(text, root.home)
        var keys = Object.keys(next)
        while (keys.length > 32) delete next[keys.shift()]
        root.cache = next
      }
    }
    onExited: {
      watchdog.stop()
      root.inflight = ""
      root.superseded = false
      if (root.host) root.host.requery({ catalog: false, provider: root.provider.id })
    }
  }

  // Hidden walks of a huge home can take a while; whatever fd printed by then
  // is still a set of real matches, so the partial output is kept.
  Timer { id: watchdog; interval: 3000; onTriggered: if (fd.running) fd.signal(15) }

  function cancelWalk() {
    if (fd.running && !root.superseded) { root.superseded = true; fd.signal(15) }
  }

  function start(key, query, settings) {
    if (fd.running) {
      if (!root.superseded) { root.superseded = true; fd.signal(15) }
      return
    }
    root.inflight = key
    fd.forKey = key
    fd.command = Files.argv(query, root.home, settings)
    fd.running = true
    watchdog.restart()
  }

  function navRow(score) {
    return { id: "files", title: "Search Files", subtitle: "Files and folders under ~", icon: "󰈞", section: "Files",
             verb: "Open", tier: "item", score: score, order: 6, action: { type: "navigate", scope: "files", title: "Files" } }
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope !== "files") return []
    var req = Files.request(ctx.query, ctx.settings, !!ctx.scope)
    var rows = []
    if (!ctx.scope && !req.explicit) {
      if (!ctx.query) return [navRow(20)]
      var s = Match.match(ctx.query, "Search Files", "files folders finder home")
      if (s) rows.push(navRow(s))
    }
    if (!req.enabled) { root.cancelWalk(); return rows }
    if (!root.available) {
      if (ctx.scope || req.explicit) rows.push({ id: "missing", title: "fd is not installed", subtitle: "sudo pacman -S fd, then search again", icon: "󰈞",
                                 section: "Files", verb: "", tier: "item", disabled: true, score: 1, action: { type: "noop" } })
      return rows
    }
    var key = Files.cacheKey(req.query, req.settings)
    if (!key) {
      root.cancelWalk()
      if (req.explicit || ctx.scope) rows.push({ id:"hint", title:"Type a file or folder name", subtitle:"At least two characters · Searches under ~", icon:"󰈞",
        section:"Files", tier:"item", score:1, disabled:true, action:{type:"noop"} })
      return rows
    }
    var hit = root.cache[key]
    if (hit === undefined) {
      if (root.inflight !== key || root.superseded) root.start(key, req.query, req.settings)
      ctx.pending()
      return rows
    }
    if (root.inflight && root.inflight !== key) root.cancelWalk()
    return rows.concat(Files.rows(req.query, hit, req.settings, !!ctx.scope || req.explicit))
  }
}
