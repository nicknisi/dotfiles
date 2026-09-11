.pragma library

// Provider patterns: regular expressions a provider declares on its provider
// object so the host can tell, before calling query(), that a query is shaped
// like something the provider answers. A matched pattern lifts every row the
// provider returns for that query by its `boost` (the largest one wins), and
// the provider sees the matched ids in ctx.patterns so it can tailor rows.
//
//   patterns: [ { id: "assignment", regex: "^\\s*[a-z_]\\w*\\s*=", flags: "i", boost: 12,
//                 example: "price = 10", description: "Assigns a variable" } ]
//
// Patterns are compiled once per registry rebuild; an invalid one is reported
// and skipped, the rest keep working. They run on the UI thread for every
// keystroke, so keep them linear (no nested quantifiers over the same text).

var MAX_PATTERNS = 64
var MAX_REGEX_LENGTH = 400
var MAX_BOOST = 100

function safeString(v, limit) { return String(v === undefined || v === null ? "" : v).replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, limit || 200) }

// -> { patterns: [{ id, regex (RegExp), boost, example, description }], errors: ["…"] }
function compile(list) {
  var out = [], errors = []
  if (!Array.isArray(list)) return { patterns: out, errors: list === undefined || list === null ? [] : ["patterns must be an array"] }
  for (var i = 0; i < list.length && out.length < MAX_PATTERNS; i++) {
    var p = list[i]
    if (!p || typeof p !== "object") { errors.push("pattern " + i + " is not an object"); continue }
    var id = safeString(p.id, 80) || "pattern-" + i
    var source = typeof p.regex === "string" ? p.regex : p.regex instanceof RegExp ? p.regex.source : ""
    if (!source) { errors.push(id + ": regex is missing"); continue }
    if (source.length > MAX_REGEX_LENGTH) { errors.push(id + ": regex longer than " + MAX_REGEX_LENGTH + " characters"); continue }
    var flags = typeof p.flags === "string" ? p.flags : p.regex instanceof RegExp ? p.regex.flags : ""
    if (/[^imsu]/.test(flags)) { errors.push(id + ": flags may only be i, m, s, u"); continue }
    var re
    try { re = new RegExp(source, flags) } catch (e) { errors.push(id + ": " + (e.message || e)); continue }
    var boost = Number(p.boost)
    if (!isFinite(boost)) boost = 10
    boost = Math.max(0, Math.min(MAX_BOOST, boost))
    out.push({ id: id, regex: re, boost: boost, example: safeString(p.example, 120), description: safeString(p.description, 200) })
  }
  return { patterns: out, errors: errors }
}

// Compiled patterns against one query -> { matched: [ids], boost }.
function evaluate(compiled, query) {
  var q = String(query || "")
  var matched = [], boost = 0
  if (!compiled || !compiled.length || !q) return { matched: matched, boost: 0 }
  for (var i = 0; i < compiled.length; i++) {
    var p = compiled[i]
    p.regex.lastIndex = 0
    if (!p.regex.test(q)) continue
    matched.push(p.id)
    if (p.boost > boost) boost = p.boost
  }
  return { matched: matched, boost: boost }
}

// "price = 10, $120 - 30%, now + 90 days" for Settings and the Extensions screen.
function examples(compiled, limit) {
  var out = []
  for (var i = 0; i < (compiled || []).length && out.length < (limit || 6); i++) if (compiled[i].example) out.push(compiled[i].example)
  return out
}
