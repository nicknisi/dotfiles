.pragma library

// Fuzzy matcher and host-owned ranking.
//
// The matcher is fzf's algorithm (FuzzyMatchV2: Smith-Waterman with affine
// gaps and position bonuses for word starts, camelCase and digits) written
// for the QML engine. Every provider scores through match(); the host also
// calls it for rows that leave `score` out. Scores are meaningful only within
// a tier: 100 is a whole-word prefix match ("chro" on "Google Chrome"), an
// exact title adds 20, gaps and mid-word starts cost points, and a match
// found only in the breadcrumb path or the keywords is discounted so a hit
// on the title itself always sorts first.
//
// Queries with several words are AND-ed, each word scored on its own, so
// "ai prov" finds "AI & Web Search › Preferred assistant" in either order.
// Typing "keysepro" walks the path Keystroke Settings › … › provider: the
// path is one haystack, and letters may jump from word start to word start.

var TIERS = { answer: 3, item: 2, fallback: 1 }

// fzf's bonuses, with a smaller per-character score than fzf's 16: a palette
// caps its list, so letters that land on word starts or extend a run must
// outweigh letters picked from the middle of unrelated words, and MIN_SCORE
// then drops the alignments that are mostly the latter ("chrome" scattered
// through "Clipboard History … existing history").
// A gap never costs more than GAP_CAP: skipping a whole breadcrumb segment
// ("keysepro" jumping from Settings to provider) is as cheap as skipping a
// few letters, so a walk through the path beats an alias with short gaps.
var SCORE_MATCH = 8, GAP_START = 3, GAP_EXTEND = 1, GAP_CAP = 8
var BONUS_BOUNDARY = 8, BONUS_WHITE = 10, BONUS_DELIMITER = 9, BONUS_CAMEL = 7, BONUS_CONSECUTIVE = 4
var FIRST_CHAR_MULTIPLIER = 2
var EXACT_BONUS = 20, PATH_WEIGHT = 0.97, KEYWORD_WEIGHT = 0.92, LENGTH_TAX = 0.02, MIN_SCORE = 40
var NONE = -1000000

var C_WHITE = 0, C_NONWORD = 1, C_DELIMITER = 2, C_LOWER = 3, C_UPPER = 4, C_DIGIT = 5

function classOf(code) {
  if (code === 32 || code === 9 || code === 10 || code === 160) return C_WHITE
  if (code >= 97 && code <= 122) return C_LOWER
  if (code >= 65 && code <= 90) return C_UPPER
  if (code >= 48 && code <= 57) return C_DIGIT
  if (code === 47 || code === 44 || code === 58 || code === 59 || code === 124 || code === 0x203a || code === 0x2192) return C_DELIMITER
  if (code < 128) return C_NONWORD
  var ch = String.fromCharCode(code)
  if (ch.toLowerCase() !== ch) return C_UPPER
  if (ch.toUpperCase() !== ch) return C_LOWER
  return C_NONWORD
}

function bonusFor(prev, cur) {
  if (cur >= C_LOWER) {
    if (prev === C_WHITE) return BONUS_WHITE
    if (prev === C_DELIMITER) return BONUS_DELIMITER
    if (prev === C_NONWORD) return BONUS_BOUNDARY
    if (cur === C_UPPER && prev === C_LOWER) return BONUS_CAMEL
    if (cur === C_DIGIT && prev !== C_DIGIT) return BONUS_CAMEL
    return 0
  }
  if (cur === C_NONWORD || cur === C_DELIMITER) return BONUS_BOUNDARY
  return BONUS_WHITE
}

// Lower-cased code points and per-position bonuses are computed once per
// distinct haystack; providers hand the same strings in on every keystroke.
var prepared = ({}), preparedCount = 0

function prepare(text) {
  var hit = prepared[text]
  if (hit) return hit
  var m = text.length
  var lower = text.toLowerCase()
  var simple = lower.length === m
  var codes = new Int32Array(m), bonus = new Int16Array(m)
  var prev = C_WHITE
  for (var j = 0; j < m; j++) {
    var code = text.charCodeAt(j)
    var cls = classOf(code)
    if (simple) codes[j] = lower.charCodeAt(j)
    else { var lc = String.fromCharCode(code).toLowerCase(); codes[j] = lc.length === 1 ? lc.charCodeAt(0) : code }
    bonus[j] = bonusFor(prev, cls)
    prev = cls
  }
  if (preparedCount >= 6000) { prepared = ({}); preparedCount = 0 }
  hit = { codes: codes, bonus: bonus, length: m }
  prepared[text] = hit
  preparedCount++
  return hit
}

var queryCache = ({ text: null, terms: null })

function termsOf(query) {
  if (queryCache.text === query) return queryCache.terms
  var parts = query.toLowerCase().split(/\s+/)
  var terms = []
  for (var i = 0; i < parts.length; i++) {
    if (!parts[i]) continue
    var n = parts[i].length
    var codes = new Int32Array(n)
    for (var c = 0; c < n; c++) codes[c] = parts[i].charCodeAt(c)
    terms.push({ text: parts[i], codes: codes, length: n, ideal: SCORE_MATCH + BONUS_WHITE * FIRST_CHAR_MULTIPLIER + (n - 1) * (SCORE_MATCH + BONUS_WHITE) })
  }
  queryCache = { text: query, terms: terms }
  return terms
}

// Reused between calls; grown on demand.
var hPrev = new Int32Array(64), hCur = new Int32Array(64), cPrev = new Int16Array(64), cCur = new Int16Array(64)

function ensure(size) {
  if (hPrev.length >= size) return
  var cap = Math.max(size, hPrev.length * 2)
  hPrev = new Int32Array(cap); hCur = new Int32Array(cap)
  cPrev = new Int16Array(cap); cCur = new Int16Array(cap)
}

// Raw fzf score of one term against one prepared haystack. Sets lastFull to
// the best alignment anywhere and lastLimited to the best one that ends
// before `limit` (the path portion of a path+keywords string); NONE if none.
var lastFull = NONE, lastLimited = NONE

function termScore(term, t, limit) {
  lastFull = NONE; lastLimited = NONE
  var n = term.length, m = t.length
  if (n === 0 || n > m) return
  var q = term.codes, codes = t.codes, bonus = t.bonus
  var first = -1, pi = 0, j
  for (j = 0; j < m && pi < n; j++) {
    if (codes[j] === q[pi]) { if (pi === 0) first = j; pi++ }
  }
  if (pi < n) return
  var last = m - 1
  while (codes[last] !== q[n - 1]) last--
  var s
  if (n === 1) {
    for (j = first; j <= last; j++) {
      if (codes[j] !== q[0]) continue
      s = SCORE_MATCH + bonus[j] * FIRST_CHAR_MULTIPLIER
      if (s > lastFull) lastFull = s
      if (j < limit && s > lastLimited) lastLimited = s
    }
    return
  }
  ensure(m + 1)
  var H = hPrev, C = cPrev, H2 = hCur, C2 = cCur, tmp
  var inGap = false, s1, s2, cons, b, fb, floor = NONE
  for (j = first; j <= last; j++) {
    if (codes[j] === q[0]) { s1 = SCORE_MATCH + bonus[j] * FIRST_CHAR_MULTIPLIER; cons = 1 } else { s1 = NONE; cons = 0 }
    s2 = j > first ? H[j - 1] - (inGap ? GAP_EXTEND : GAP_START) : NONE
    if (floor > s2) s2 = floor
    if (s1 >= s2) { H[j] = s1; C[j] = cons; inGap = false; if (s1 - GAP_CAP > floor) floor = s1 - GAP_CAP } else { H[j] = s2; C[j] = 0; inGap = true }
  }
  for (var i = 1; i < n; i++) {
    var qi = q[i], from = first + i, to = last - (n - 1 - i)
    inGap = false; floor = NONE
    for (j = from; j <= to; j++) {
      s1 = NONE; cons = 0
      if (codes[j] === qi && H[j - 1] > NONE) {
        b = bonus[j]
        cons = C[j - 1] + 1
        if (cons > 1) {
          fb = bonus[j - cons + 1]
          if (b >= BONUS_BOUNDARY && b > fb) cons = 1
          else { if (fb > b) b = fb; if (BONUS_CONSECUTIVE > b) b = BONUS_CONSECUTIVE }
        }
        s1 = H[j - 1] + SCORE_MATCH + b
      }
      s2 = j > from ? H2[j - 1] - (inGap ? GAP_EXTEND : GAP_START) : NONE
      if (floor > s2) s2 = floor
      if (s1 >= s2) { H2[j] = s1; C2[j] = cons; inGap = false; if (s1 - GAP_CAP > floor) floor = s1 - GAP_CAP } else { H2[j] = s2; C2[j] = 0; inGap = true }
    }
    tmp = H; H = H2; H2 = tmp
    tmp = C; C = C2; C2 = tmp
  }
  for (j = first + n - 1; j <= last; j++) {
    if (C[j] <= 0) continue
    s = H[j]
    if (s > lastFull) lastFull = s
    if (j < limit && s > lastLimited) lastLimited = s
  }
}

function normalize(raw, ideal, length) {
  if (raw === NONE) return 0
  var out = 100 * raw / ideal - LENGTH_TAX * Math.min(length, 200)
  return out > 0 ? out : 0.01
}

// Scores every term (all must match) against one string. Sets scoreFull for
// the whole string and scoreLimited for its first `limit` characters. The
// length tiebreak uses the row's title, not the haystack, so a deep item
// with a long breadcrumb does not lose an equal match to a shallow one.
var scoreFull = 0, scoreLimited = 0

function scoreTerms(terms, t, limit, titleLength) {
  var rawFull = 0, rawLimited = 0, ideal = 0
  for (var i = 0; i < terms.length; i++) {
    termScore(terms[i], t, limit)
    if (lastFull === NONE) { scoreFull = 0; scoreLimited = 0; return }
    rawFull += lastFull
    if (rawLimited !== NONE) rawLimited = lastLimited === NONE ? NONE : rawLimited + lastLimited
    ideal += terms[i].ideal
  }
  scoreFull = normalize(rawFull, ideal, titleLength)
  scoreLimited = normalize(rawLimited, ideal, titleLength)
}

// 0..100 for a query (every word must match) against one string; 0 if not.
function score(query, text) {
  var terms = termsOf(String(query || ""))
  if (!terms.length) return 0
  var t = prepare(String(text || ""))
  scoreTerms(terms, t, t.length, t.length)
  return scoreFull
}

// Path + " " + keywords strings are looked up, never rebuilt, per keystroke.
var joinedCache = ({}), joinedCount = 0

function joined(base, extra) {
  var inner = joinedCache[base]
  if (!inner) {
    if (joinedCount >= 6000) { joinedCache = ({}); joinedCount = 0 }
    inner = ({}); joinedCache[base] = inner
  }
  var out = inner[extra]
  if (!out) { out = base + " " + extra; inner[extra] = out; joinedCount++ }
  return out
}

// Long prose (descriptions, clipboard text) is not fuzzy-matched: scattered
// letters would hit almost any sentence. Every query word must instead be a
// prefix of a word in it, for a flat score.
var WORD_SCORE = 50, WORD_SPLIT = /[^0-9a-z_ª-￿]+/
var wordsCache = ({}), wordsCount = 0

function wordsOf(text) {
  var hit = wordsCache[text]
  if (hit) return hit
  if (wordsCount >= 6000) { wordsCache = ({}); wordsCount = 0 }
  hit = text.toLowerCase().split(WORD_SPLIT)
  wordsCache[text] = hit
  wordsCount++
  return hit
}

function wordPrefixed(terms, text) {
  var ws = wordsOf(text)
  for (var t = 0; t < terms.length; t++) {
    var term = terms[t].text, found = false
    for (var i = 0; i < ws.length; i++) if (ws[i].indexOf(term) === 0) { found = true; break }
    if (!found) return false
  }
  return true
}

// title: the row's own name. keywords: identifiers a user may abbreviate
// (aliases, ids, config keys, option values), fuzzy like the title. path: the
// breadcrumb ending in the title, for rows reachable through submenus
// ("Keystroke Settings › AI & Web Search › Preferred assistant").
// description: synonyms and prose, matched by word prefix only.
function match(query, title, keywords, path, description) {
  var q = String(query || "").trim()
  if (!q) return 1
  var terms = termsOf(q)
  if (!terms.length) return 1
  var name = String(title || "")
  var tName = prepare(name)
  scoreTerms(terms, tName, tName.length, tName.length)
  var best = scoreFull
  if (best > 0 && name.toLowerCase() === q.toLowerCase()) best += EXACT_BONUS
  var trail = String(path || ""), extra = String(keywords || ""), prose = String(description || "")
  var base = trail || name
  var full = extra ? joined(base, extra) : base
  if (trail || extra) {
    scoreTerms(terms, prepare(full), base.length, tName.length)
    if (trail && trail !== name) {
      var sp = scoreLimited * PATH_WEIGHT
      if (sp > best) best = sp
    }
    if (extra) {
      var sk = scoreFull * KEYWORD_WEIGHT
      if (sk > best) best = sk
    }
  }
  if (best < WORD_SCORE && prose && q.length >= 2 && wordPrefixed(terms, joined(full, prose))) best = WORD_SCORE
  return best >= MIN_SCORE ? best : 0
}

function tierValue(row) {
  return TIERS[row && row.tier] || TIERS.item
}

// bonus(row) is the frecency bonus; it only ever reorders within the item
// tier, so learning can never promote a row above a computed answer or push
// a fallback above a real match.
// The frecency bonus is computed once per row, never inside the comparator:
// a sort asks for O(n log n) comparisons and each bonus is a hash lookup.
function rank(rows, bonus) {
  var items = new Array(rows.length)
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i], tier = tierValue(row), score = Number(row.score || 0)
    if (tier === TIERS.item && bonus) score += bonus(row)
    items[i] = { row: row, tier: tier, score: score, order: row.order === undefined ? 50 : row.order, name: null }
  }
  items.sort(function(a, b) {
    if (a.tier !== b.tier) return b.tier - a.tier
    if (a.score !== b.score) return b.score - a.score
    if (a.order !== b.order) return a.order - b.order
    if (a.name === null) a.name = String(a.row.title || "").toLowerCase()
    if (b.name === null) b.name = String(b.row.title || "").toLowerCase()
    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
  })
  var out = new Array(items.length)
  for (i = 0; i < items.length; i++) out[i] = items[i].row
  return out
}
