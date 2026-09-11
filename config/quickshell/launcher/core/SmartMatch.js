.pragma library
.import "Match.js" as Match
.import "Intent.js" as Intent

var SCHEMA = [
  { key: "mode", type: "enum", label: "Smart match", description: "Match queries using an embedding model", "default": "all",
    options: ["off", "voice", "all"], optionLabels: { off: "Off", voice: "Only voice", all: "Voice and text" } },
  { key: "model", type: "enum", label: "Matching model", description: "Small uses less memory; large understands more phrasing", "default": "small",
    options: ["small", "large"], optionLabels: { small: "Small (2M)", large: "Large (8M)" } }
]

function enabled(mode, voice) { return mode === "all" || (mode === "voice" && voice) }
function request(raw) {
  var text = String(raw || "").trim(), lower = text.toLowerCase().replace(/[\u2018\u2019]/g, "'")
  lower = lower.replace(/^(?:please\s+)?(?:(?:can|could) you\s+)?(?:please\s+)?/, "")
  var blocked = /\b(?:don't|dont|do not|never|cancel|not installed)\b/.test(lower) || /^(?:how|why|write|tell)\b/.test(lower)
  var q = Intent.normalize(text).toLowerCase()
  q = q.replace(/^(?:change|choose|select)(?:\s+(?:the|a|my|different))*\s+/, "").replace(/^take\s+/, "")
    .replace(/^capture (?:my )?screen$/, "screenshot").replace(/\bscreen shot\b/g, "screenshot").replace(/\bnight light\b/g, "nightlight")
  var family = ""
  if (/\b(?:remove|uninstall|delete)\b/.test(lower)) family = "remove"
  else if (/\binstall\b/.test(lower)) family = "install"
  else if (/\b(?:default|preferred)\b/.test(lower)) family = "default"
  else if (/\b(?:screen ?record|recording|record the screen|record screen)\b/.test(lower)) family = /\bstop\b/.test(lower) ? "record-stop" : "record-start"
  else if (/\b(?:restart|reboot)\b/.test(lower)) family = "restart"
  else if (/^(?:please\s+)?(?:change|choose|select|switch)\b/.test(lower)) family = "change"
  else if (/^(?:please\s+)?(?:launch|open|run|start)\b/.test(lower)) family = "open"
  if (family === "restart") q = q.replace(/^restart\s+/, "").replace(/\bblue tooth\b/g, "bluetooth")
  var direction = /\b(?:up|increase|louder)\b/.test(lower) ? "up" : /\b(?:down|decrease|quieter)\b/.test(lower) ? "down" : ""
  var state = /^(?:please\s+)?(?:(?:turn|switch)\s+on|enable)\b/.test(lower) ? "on" : /^(?:please\s+)?(?:(?:turn|switch)\s+off|disable)\b/.test(lower) ? "off" : ""
  return { text: text, query: q, blocked: blocked, family: family, direction: direction, state: state, math: Intent.arithmetic(text) }
}

// The result is memoized on the row (catalog rows live across keystrokes;
// a provider may also declare intentFamily itself).
function family(row) {
  if (row.intentFamily) return row.intentFamily
  return (row.intentFamily = computeFamily(row))
}

function computeFamily(row) {
  var id = row.id || "", a = row.action || {}, title = String(row.title || "").toLowerCase()
  if (row.providerKey === "omarchy") {
    if (id.indexOf("remove.") === 0) return "remove"
    if (id.indexOf("install.") === 0) return "install"
    if (id.indexOf("setup.default.") === 0) return "default"
    if (id === "system.reboot" || id.indexOf("update.hardware.") === 0) return "restart"
    if (id === "trigger.capture.screenrecord.stop") return "record-stop"
    if (id.indexOf("trigger.capture.screenrecord") === 0) return "record-start"
  }
  if (a.type === "app" || (row.providerKey === "hotkeys" && /^(?:browser|terminal|file manager)(?: \(cwd\))?$/.test(title))) return "launch"
  if (/^enable\b/.test(title)) return "enable"
  if (/^disable\b/.test(title)) return "disable"
  if (/^toggle\b/.test(title) || /\bomarchy-toggle-/.test(a.command || a.arg || "")) return "toggle"
  if (a.type === "navigate" || a.type === "provider-view") return "navigate"
  if (/\b(?:reboot|restart)\b/.test(title)) return "restart"
  if (/\b(?:screenrecord|screen recording)\b/.test(title)) return "record-toggle"
  return "action"
}

// Everything allowed() reads from the request, so a catalog filtered under one
// key can be reused for every query that shares it.
function constraintKey(req) {
  return [req.blocked ? 1 : 0, req.state, req.family, req.direction,
          /\b(?:shutdown|shut down|logout|log out|hibernate|reset)\b/i.test(req.text) ? 1 : 0,
          /\b(?:volume|brightness)\b/i.test(req.text) ? 1 : 0].join("|")
}

function allowed(req, row, semantic) {
  if (semantic && (row.disabled || row.tier !== "item")) return false
  if (req.blocked) return row.tier === "fallback" || row.tier === "answer"
  if (row.tier !== "item") return true
  var f = family(row), a = row.action || {}
  if (req.state) {
    if (a.type === "setting" && typeof a.value === "boolean") return a.value === (req.state === "on")
    if (f !== "toggle" && f !== (req.state === "on" ? "enable" : "disable")) return false
  }
  if (req.family === "open" && f !== "launch" && f !== "navigate") return false
  if ((f === "remove" || f === "install" || f === "default") && req.family !== f && (semantic || req.family)) return false
  if ((req.family === "remove" || req.family === "install" || req.family === "default") && req.family !== f) return false
  if (req.family.indexOf("record-") === 0 && f !== req.family) return false
  if (req.family === "restart" && f !== "restart") return false
  // Shutdown/reset are not semantic guesses for an unrelated request.
  if (semantic && row.confirm && !req.family && !/\b(?:shutdown|shut down|logout|log out|hibernate|reset)\b/i.test(req.text)) return false
  var name = String(row.title || "").toLowerCase()
  if (req.direction && /\b(?:volume|brightness)\b/i.test(req.text)) {
    if (!/volume|brightness/.test(name)) return false
    if (req.direction === "up" && !/\b(?:up|increase)\b/.test(name)) return false
    if (req.direction === "down" && !/\b(?:down|decrease)\b/.test(name)) return false
  }
  return true
}

function editOne(a, b) {
  if (Math.abs(a.length - b.length) > 1) return false
  var i = 0, j = 0, edits = 0
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) { i++; j++; continue }
    if (++edits > 1) return false
    if (a.length === b.length && a[i] === b[j + 1] && a[i + 1] === b[j]) { i += 2; j += 2 }
    else if (a.length > b.length) i++
    else if (a.length < b.length) j++
    else { i++; j++ }
  }
  return edits + (i < a.length || j < b.length ? 1 : 0) <= 1
}

function lexicalWords(row) {
  if (row.lexicalWords) return row.lexicalWords
  return (row.lexicalWords = ((row.title || "") + " " + (row.keywords || "")).toLowerCase().split(/[^a-z0-9]+/))
}

function lexical(req, row, hasChrome) {
  if (!allowed(req, row, true)) return 0
  var q = req.query, name = row.title || ""
  var score = Match.match(q, name, row.keywords, row.path, row.description)
  if (!hasChrome && row.providerKey === "applications" && q.replace(/[^a-z0-9]/g, "") === "chrome" && /^chromium(?:\.desktop)?$/.test(row.id)) score = Math.max(score, 105)
  if (!score && q.length >= 4 && q.length <= 80) {
    var words = lexicalWords(row)
    if (q.split(/\s+/).every(function(t) { return words.some(function(w) { return t === w || (t.length >= 4 && editOne(t, w)) }) })) score = 72
  }
  if (score && family(row) === "launch") score += req.family === "open" ? 45 : 8
  return score
}

function document(row) {
  return ((row.path || row.title) + ". " + (row.keywords || "") + " " + (row.description || "") + " " + (row.intentDescription || "")).trim().slice(0, 4096)
}

function effectKey(row) {
  var a = row.action || {}, key
  if (a.type === "shell") key = "command:" + a.command
  else if (a.type === "hotkey" && a.dispatcher === "exec") key = "command:" + a.arg
  else if (a.type === "app") key = "app:" + String(a.id || row.id).replace(/\.desktop$/, "")
  else key = JSON.stringify(a)
  // Provider-private actions can depend on row data even when their payload is empty.
  if (["shell", "hotkey", "app", "navigate", "setting"].indexOf(a.type) < 0) key = row.uid
  return key + (row.altAction ? JSON.stringify(row.altAction) : "")
}

function hasChrome(catalog) {
  for (var i = 0; i < catalog.length; i++) if (catalog[i].providerKey === "applications" && /^google-chrome(?:\.desktop)?$/.test(catalog[i].id)) return true
  return false
}

// Documents for the helper: IDs and descriptive text only, bounded in size.
// The signature identifies this exact catalog so an unchanged one is neither
// re-serialized per keystroke nor re-sent to the helper.
function documents(catalog, req) {
  var out = [], size = 0, joined = []
  for (var i = 0; i < catalog.length; i++) {
    if (!allowed(req, catalog[i], true)) continue
    var text = document(catalog[i])
    size += catalog[i].uid.length + text.length + 24
    if (size > 3 * 1024 * 1024) break
    out.push({ id: catalog[i].uid, text: text })
    joined.push(catalog[i].uid, text)
  }
  return { rows: out, signature: out.length ? Qt.md5(joined.join("\u001f")) : "" }
}

// `cache` (optional, owned by the host per catalog) keeps the lexical scores of
// the last query text: the refreshes that follow one keystroke reuse them.
function lexicalScores(catalog, req, chrome, cache) {
  if (cache && cache.text === req.text && cache.scores && cache.scores.length === catalog.length) return cache.scores
  var scores = new Array(catalog.length)
  for (var i = 0; i < catalog.length; i++) scores[i] = lexical(req, catalog[i], chrome)
  if (cache) { cache.text = req.text; cache.scores = scores }
  return scores
}

function merge(base, catalog, req, matches, chrome, cache) {
  var out = [], byId = ({}), candidates = ({}), i
  if (chrome === undefined) chrome = hasChrome(catalog)
  var scores = lexicalScores(catalog, req, chrome, cache)
  function put(row, score, semantic) {
    if (!score || !allowed(req, row, semantic)) return
    var old = byId[row.uid]
    if (old) { old.score = Math.max(old.score, score); return }
    var copy = {}
    for (var k in row) copy[k] = row[k]
    copy.score = score
    if (req.state && family(row) === "toggle") copy.verb = "Toggle"
    if (semantic) { copy.smartMatch = true; copy.hint = copy.hint || "Suggested match" }
    byId[row.uid] = copy; out.push(copy)
  }
  for (i = 0; i < base.length; i++) put(base[i], base[i].score, false)
  for (i = 0; i < catalog.length; i++) {
    var row = catalog[i]
    candidates[row.uid] = row
    put(row, scores[i], false)
  }
  // Similarity generates suggestions, not an execution-confidence decision.
  // Exact lexical hits start above semantic-only suggestions; the host applies
  // learned preferences afterward. Enter still runs the selected action.
  for (i = 0; i < (matches || []).length && i < 30; i++) {
    var hit = matches[i], candidate = candidates[hit.id]
    if (candidate && typeof hit.score === "number" && isFinite(hit.score) && hit.score >= 0.5)
      put(candidate, 40 + Math.min(1, hit.score) * 35, true)
  }
  var unique = [], byEffect = ({})
  for (i = 0; i < out.length; i++) {
    var item = out[i], key = effectKey(item), prior = byEffect[key]
    if (!prior) { byEffect[key] = item; unique.push(item); continue }
    // Never lose a confirmation by choosing the equivalent unconfirmed hotkey.
    if ((!prior.confirm && item.confirm) || (!!prior.confirm === !!item.confirm && item.score > prior.score)) {
      unique[unique.indexOf(prior)] = item; byEffect[key] = item
    }
  }
  return unique
}
