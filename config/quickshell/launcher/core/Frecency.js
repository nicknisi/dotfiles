.pragma library

// Local selection frecency: opaque hashed ids, decaying weights, timestamps.
// Pure functions over a plain entries object; the host owns the file.

var HALF_LIFE = 14 * 86400
var MAX_ENTRIES = 2000
var MAX_BONUS = 36
var MAX_QUERY_BONUS = 108
// An item key is one hash; a learned query key is the item hash, a colon and
// a hash of the scope and normalized query. Both stay opaque on disk.
var KEY_SHAPE = /^[0-9a-f]{32}(?::[0-9a-f]{32})?$/

function parse(text) {
  var entries = {}
  try {
    var data = JSON.parse(String(text || ""))
    if (!data || data.version !== 1 || typeof data.entries !== "object") return entries
    for (var key in data.entries) {
      var e = data.entries[key]
      if (!e || typeof key !== "string" || !KEY_SHAPE.test(key)) continue
      var w = Number(e.weight), u = Number(e.updated)
      if (!isFinite(w) || !isFinite(u) || w < 0 || w > 1e6) continue
      entries[key] = { weight: w, updated: u }
    }
  } catch (err) { }
  return entries
}

function serialize(entries) {
  return JSON.stringify({ version: 1, entries: entries }) + "\n"
}

// Qt.md5 costs about 25 µs per call in the QML engine, and ranking asks for
// a key per row on every keystroke: hashes are memoized. The item hash never
// changes; the query-context hash changes only when the query or scope does.
var keyCache = ({}), keyCacheCount = 0
function key(providerId, rowId) {
  var plain = String(providerId) + "/" + String(rowId)
  var hit = keyCache[plain]
  if (hit) return hit
  if (keyCacheCount >= 8000) { keyCache = ({}); keyCacheCount = 0 }
  hit = Qt.md5(plain)
  keyCache[plain] = hit
  keyCacheCount++
  return hit
}

// Separate namespace preserves existing usage data without storing search text.
// Learn the actual query, not the embedding rewrite; scope keeps intent local.
var contextCache = { plain: null, hash: "" }
function contextKey(query, scope) {
  var normalized = String(query || "").trim().toLowerCase().replace(/\s+/g, " ")
  if (!normalized) return ""
  var plain = String(scope || "") + "\n" + normalized
  if (contextCache.plain !== plain) contextCache = { plain: plain, hash: Qt.md5(plain) }
  return contextCache.hash
}

function queryKey(providerId, rowId, query, scope) {
  var context = contextKey(query, scope)
  return context ? key(providerId, rowId) + ":" + context : ""
}

function queryBonus(entries, k, now) {
  if (!k) return 0
  return Math.min(MAX_QUERY_BONUS, 72 * Math.log2(1 + weight(entries, k, now)))
}

function weight(entries, k, now) {
  var e = entries[k]
  if (!e) return 0
  return e.weight * Math.pow(2, -Math.max(0, now - e.updated) / HALF_LIFE)
}

function bonus(entries, k, now) {
  if (!k) return 0
  return Math.min(MAX_BONUS, 12 * Math.log2(1 + weight(entries, k, now)))
}

function record(entries, k, now) {
  var next = {}
  for (var existing in entries) next[existing] = entries[existing]
  next[k] = { weight: Math.min(1e6, weight(entries, k, now) + 1), updated: now }
  var keys = Object.keys(next)
  if (keys.length > MAX_ENTRIES) {
    keys.sort(function(a, b) { return weight(next, b, now) - weight(next, a, now) })
    var pruned = {}
    for (var i = 0; i < MAX_ENTRIES; i++) pruned[keys[i]] = next[keys[i]]
    next = pruned
  }
  return next
}
