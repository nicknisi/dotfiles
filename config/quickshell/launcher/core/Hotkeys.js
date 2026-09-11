.pragma library
.import "Match.js" as Match

// The helper reads live Hyprland data and emits validated, literal argv.
function loadArgv(helperPath) { return ["luajit", String(helperPath)] }
function dispatchArgv(bind) {
  if (!bind || !Array.isArray(bind.argv) || !bind.argv.length) return []
  if (bind.release || bind.longPress || bind.mouse || bind.submap || bind.catch_all || bind.enabled === false) return []
  for (var i = 0; i < bind.argv.length; i++)
    if (typeof bind.argv[i] !== "string" || bind.argv[i].indexOf("\u0000") >= 0) return []
  if (bind.dispatcher === "__lua") {
    var registration = bind.registration
    if (!registration || typeof registration.generation !== "string" || !/^[0-9a-f]{32}$/.test(registration.generation)
        || typeof registration.id !== "number" || registration.id % 1 !== 0 || registration.id < 1 || registration.id > 1024) return []
    var expression = '_G.launcher_bindings.resolve("' + registration.generation + '", ' + registration.id + ')'
    if (JSON.stringify(bind.argv) !== JSON.stringify(["hyprctl", "dispatch", expression])) return []
  }
  return bind.argv.slice()
}

function slug(text) {
  return String(text || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

// Merge identical actions while keeping submaps and trigger modes distinct.
function parse(text) {
  var records
  try { records = JSON.parse(String(text || "[]")) } catch (e) { return [] }
  var binds = [], byAction = ({}), byLabel = ({})
  for (var i = 0; Array.isArray(records) && i < records.length; i++) {
    var record = records[i]
    if (!record || !record.combo || !record.label) continue
    var actionKey = JSON.stringify([record.label, record.dispatcher, record.arg, record.argv, record.registration, record.submap, record.release, record.repeat, record.longPress, record.mouse, record.catch_all, record.enabled])
    var hit = byAction[actionKey]
    if (hit) { if (hit.combos.indexOf(record.combo) < 0) hit.combos.push(record.combo); continue }
    var id = slug(record.label) || "bind", n = (byLabel[id] || 0) + 1
    byLabel[id] = n
    if (n > 1) id += "-" + n
    var bind = { id: id, label: String(record.label), combos: [String(record.combo)], dispatcher: String(record.dispatcher || ""),
                 arg: String(record.arg || ""), argv: dispatchArgv(record), registration: record.registration || null, submap: String(record.submap || ""),
                 release: !!record.release, repeat: !!record.repeat, longPress: !!record.longPress, mouse: !!record.mouse,
                 catch_all: !!record.catch_all, enabled: record.enabled !== false, labelHint: !!record.labelHint, order: binds.length }
    byAction[actionKey] = bind
    binds.push(bind)
  }
  return binds
}

var MODIFIERS = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt" }
var KEYS = {
  RETURN: "↵", ENTER: "↵", SPACE: "Space", ESCAPE: "Esc", TAB: "Tab", BACKSPACE: "⌫", DELETE: "Del",
  PRINT: "Print", HOME: "Home", END: "End", PRIOR: "PgUp", NEXT: "PgDn", INSERT: "Ins",
  LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓",
  COMMA: ",", PERIOD: ".", MINUS: "-", EQUAL: "=", SLASH: "/", BACKSLASH: "\\", GRAVE: "`",
  BRACKETLEFT: "[", BRACKETRIGHT: "]", SEMICOLON: ";", APOSTROPHE: "'"
}

function keyName(raw) {
  var key = String(raw || "").trim()
  if (!key) return ""
  var upper = key.toUpperCase()
  if (KEYS[upper]) return KEYS[upper]
  if (key.indexOf("XF86") === 0) return key.substring(4).replace(/([a-z])([A-Z])/g, "$1 $2")
  if (/^(LEFT|RIGHT|MIDDLE) MOUSE BUTTON$/.test(upper)) return upper.charAt(0) + upper.substring(1, upper.indexOf(" ")).toLowerCase() + " click"
  if (/^[A-Z]$/.test(upper)) return upper
  if (/^F[0-9]{1,2}$/.test(upper)) return upper
  if (upper === key && key.length > 1 && !/^(code|mouse):/.test(key)) return key.charAt(0) + key.substring(1).toLowerCase()
  return key
}

// "SUPER SHIFT + RETURN" → "Super + Shift + ↵": the record's spelling, made
// readable the way the palette's own key hints are.
function keys(combo) {
  var text = String(combo || "").trim()
  if (!text) return ""
  var plus = text.lastIndexOf(" + ")
  var mods = plus < 0 ? [] : text.substring(0, plus).split(/\s+/)
  var key = plus < 0 ? text : text.substring(plus + 3)
  var parts = []
  for (var i = 0; i < mods.length; i++) if (mods[i]) parts.push(MODIFIERS[mods[i].toUpperCase()] || keyName(mods[i]))
  parts.push(keyName(key))
  return parts.join(" + ")
}

function accessory(bind) {
  var out = []
  for (var i = 0; i < bind.combos.length; i++) out.push(keys(bind.combos[i]))
  return out.join("  ·  ")
}

function runnable(bind) { return dispatchArgv(bind).length > 0 }

function subtitle(bind) {
  var detail = bind.dispatcher + (bind.arg ? " " + bind.arg : "")
  if (!runnable(bind)) return "Only from the keyboard · " + detail
  if (bind.dispatcher === "__lua") return "Registered Hyprland binding"
  return bind.dispatcher === "exec" ? bind.arg : "Hyprland " + detail
}

function comboKey(text) { return String(text || "").toLowerCase().replace(/\s*\+\s*/g, " ").replace(/\s+/g, " ").trim() }

// Abbreviations and the combo itself both find a bind: "flcrn" walks Full
// screen, "super f" lands on its keys, "screenshot" on the command it runs.
function keywords(bind) {
  if (bind.searchKeywords !== undefined) return bind.searchKeywords
  var words = []
  for (var i = 0; i < bind.combos.length; i++) words.push(comboKey(bind.combos[i]))
  if (bind.dispatcher === "exec" && bind.arg) words.push(bind.arg.split(/\s+/)[0])
  return (bind.searchKeywords = words.join(" "))
}

function row(bind, score) {
  var can = runnable(bind)
  return {
    id: bind.id, title: bind.label, subtitle: subtitle(bind), icon: "",
    section: "Hotkeys", verb: can ? "Run" : "", tier: "item", score: score, order: bind.order,
    accessory: accessory(bind), disabled: !can, remember: can,
    confirm: can && /\b(log\s*out|shut\s*down|power\s*off|reboot|restart|hibernate|close window|kill|delete|remove)\b/i.test(bind.label + " " + (bind.dispatcher === "exec" ? bind.arg : ""))
      ? "Run " + bind.label + "? Unsaved work may be lost." : "",
    previewLabel: "HOTKEY", preview: subtitle(bind),
    previewDetail: accessory(bind) + (bind.submap ? " · Submap: " + bind.submap : "") + (bind.release ? " · On release" : "") + (bind.longPress ? " · Long press" : "") + (bind.mouse ? " · Mouse trigger" : "") + (bind.repeat ? " · Repeats" : "") + (bind.labelHint ? "\nLabel hint from dotfiles defaults, not callback introspection" : ""),
    intentFamily: /stop recording/i.test(bind.label) ? "record-stop" : /record (region|window|screen)/i.test(bind.label) ? "record-start" : "",
    action: can ? { type: "hotkey", dispatcher: bind.dispatcher, arg: bind.arg, argv: bind.argv, registration: bind.registration } : { type: "noop" }
  }
}

function navRow(score) {
  return { id: "hotkeys", title: "Hotkeys", subtitle: "Live Hyprland keybindings, searchable", icon: "", section: "Hotkeys",
           verb: "Open", tier: "item", score: score, order: 8, action: { type: "navigate", scope: "hotkeys", title: "Hotkeys" } }
}

// The screen lists every bind in Hyprland's order; the root mixes
// the best `limit` matches into the global search and never the whole list.
function rows(query, binds, settings, inScreen) {
  var q = String(query || "").trim()
  var qk = comboKey(q)
  // "super + f" as people write combos: a lone plus is punctuation, not a term.
  var needle = q.replace(/(^|\s)\+(?=\s|$)/g, " ").replace(/\s+/g, " ").trim() || q
  var showKeyboardOnly = !settings || settings.keyboardOnly !== false
  var limit = settings && settings.limit > 0 ? settings.limit : 10
  var out = [], scored = []
  for (var i = 0; i < binds.length; i++) {
    var bind = binds[i]
    if (!runnable(bind) && !showKeyboardOnly) continue
    if (!q) { if (inScreen) out.push(row(bind, 1)); continue }
    var s = Match.match(needle, bind.label, keywords(bind), "", bind.dispatcher === "exec" ? bind.arg : "")
    if (!s) continue
    // The keys spelled out ("super f") name one bind; it outranks the binds that merely contain them.
    for (var c = 0; c < bind.combos.length; c++) if (comboKey(bind.combos[c]) === qk) { s += 25; break }
    if (inScreen) out.push(row(bind, s)); else scored.push({ bind: bind, score: s, order: bind.order })
  }
  if (!inScreen && q) {
    // At the root only `limit` rows survive; build just those.
    scored.sort(function(a, b) { return b.score - a.score || a.order - b.order })
    for (i = 0; i < scored.length && i < limit; i++) out.push(row(scored[i].bind, scored[i].score))
  }
  return out
}
