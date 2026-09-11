.pragma library
.import "Match.js" as Match

// File and folder search under the home folder, on top of `fd` (Omarchy's
// base package set ships it next to ripgrep and plocate). Everything here is
// pure: the provider owns the process, this module decides what to run and
// what to show.
//
// fd filters subsequences outside the UI thread; only a bounded candidate set
// reaches QML scoring. The last word must match the basename, preventing a
// matching parent directory from flooding results with unrelated children.

var MIN_QUERY = 2          // one letter matches half the disk and ranks nothing
var CANDIDATES = 400       // fd stops after this many hits; the best `limit` survive
var SCOPED_LIMIT = 60      // inside the Files screen the root limit does not apply
var WEIGHT = 0.55          // files rank below apps and Omarchy entries with the same score
var FLOOR = 12             // fd already confirmed a literal/subsequence match
var MAX_QUERY = 128

function prefixed(query) { return /^\s*~/.test(String(query || "")) }

function request(query, settings, scoped) {
  var explicit = prefixed(query)
  var q = String(query || "").trim()
  if (explicit) q = q.slice(1).replace(/^\//, "").trim()
  return { query: q, explicit: explicit,
    enabled: scoped || explicit || settings.searchMode !== "prefix",
    settings: Object.assign({}, settings, { fuzzy: scoped || explicit || settings.searchMode !== "literal" }) }
}

var IMAGE = { png: 1, jpg: 1, jpeg: 1, webp: 1, gif: 1, bmp: 1, svg: 1, avif: 1 }
var ICONS = {
  image: "󰋩", pdf: "󰈦", archive: "󰀼", audio: "󰈣", video: "󰈫",
  code: "󰈙", text: "󰈙", file: "󰈔", folder: "󰉋"
}
var KIND = {
  pdf: "pdf", zip: "archive", tar: "archive", gz: "archive", xz: "archive", zst: "archive", "7z": "archive", rar: "archive",
  mp3: "audio", flac: "audio", ogg: "audio", wav: "audio", m4a: "audio", opus: "audio",
  mp4: "video", mkv: "video", webm: "video", mov: "video", avi: "video",
  md: "text", txt: "text", json: "text", yaml: "text", yml: "text", toml: "text", conf: "text", ini: "text", csv: "text",
  js: "code", ts: "code", py: "code", rs: "code", go: "code", c: "code", h: "code", cpp: "code", sh: "code", qml: "code", html: "code", css: "code", lua: "code"
}

function words(query) {
  return String(query || "").trim().split(/[\s/]+/).filter(function(w) { return w.length > 0 })
}

// Null when there is nothing worth asking fd: too short, or both kinds off.
function cacheKey(query, settings) {
  var ws = words(query)
  if (!ws.length || ws.join("").length < MIN_QUERY || String(query).length > MAX_QUERY || ws.length > 8 || /[\u0000-\u001f]/.test(query)) return null
  if (!settings.files && !settings.folders) return null
  return ws.join(" ").toLowerCase() + "\n" + (settings.files ? "f" : "") + (settings.folders ? "d" : "") + (settings.hidden ? "h" : "") + (settings.fuzzy ? "z" : "")
}

function escapeRegex(word) {
  return word.replace(/[.*+?^${}()|[\]\\\/-]/g, "\\$&")
}

function pattern(word, fuzzy) {
  return fuzzy ? Array.from(word).map(escapeRegex).join("[^/]*") : escapeRegex(word)
}

// Literal argv, no shell: the query lands in fd's own arguments. The words
// are regex-escaped literals; the last one is anchored to the final path
// segment. Extra words go through `--and=` and the anchored one comes after
// `--`, so a word that starts with a dash is never read as a flag.
function argv(query, home, settings) {
  var ws = words(query)
  var out = ["fd", "--ignore-case", "--full-path", "--color", "never", "--absolute-path",
             "--base-directory", home, "--max-results", String(CANDIDATES), "--threads", "2", "--print0"]
  if (settings.hidden) out.push("--hidden", "--exclude", ".git")
  if (settings.files && !settings.folders) out.push("--type", "f")
  if (settings.folders && !settings.files) out.push("--type", "d")
  for (var i = 0; i < ws.length - 1; i++) out.push("--and=" + pattern(ws[i], settings.fuzzy))
  out.push("--", "[^/]*" + pattern(ws[ws.length - 1], settings.fuzzy) + "[^/]*/?$")
  return out
}

// NUL-delimited paths preserve filenames containing newlines.
function parse(output, home) {
  var lines = String(output || "").split("\u0000"), out = []
  var prefix = home.replace(/\/+$/, "") + "/"
  // A cancelled/timed-out walk may end mid-record; discard its incomplete tail.
  for (var i = 0; i < lines.length - 1; i++) {
    var line = lines[i]
    if (!line) continue
    var dir = line.charAt(line.length - 1) === "/"
    var abs = dir ? line.slice(0, -1) : line
    if (abs.indexOf(prefix) !== 0 || abs.length === prefix.length) continue
    out.push({ path: abs, rel: abs.slice(prefix.length), dir: dir })
  }
  return out
}

function baseName(rel) {
  var slash = rel.lastIndexOf("/")
  return slash >= 0 ? rel.slice(slash + 1) : rel
}

function parentOf(rel) {
  var slash = rel.lastIndexOf("/")
  return slash >= 0 ? rel.slice(0, slash) : ""
}

function extensionOf(name) {
  var dot = name.lastIndexOf(".")
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : ""
}

function kindOf(entry) {
  if (entry.dir) return "folder"
  var ext = extensionOf(baseName(entry.rel))
  if (IMAGE[ext]) return "image"
  return KIND[ext] || "file"
}

function tilde(rel) { return rel ? "~/" + rel : "~" }

// fd matched the absolute path, so a word like "home" or the user name hits
// everything; re-check below the home folder: the last word in the name, the
// others anywhere in the relative path.
function matchesRelative(entry, ws, fuzzy) {
  var hay = entry.rel.toLowerCase()
  function matches(text, word) {
    word = word.toLowerCase()
    if (!fuzzy) return text.indexOf(word) >= 0
    // Linear subsequence check; do not run a backtracking regex on the UI thread.
    for (var i = 0, j = 0; i < text.length; i++) {
      if (text.charAt(i) === "/") { j = 0; continue }
      if (text.charAt(i) === word.charAt(j) && ++j === word.length) return true
    }
    return false
  }
  if (!matches(baseName(hay), ws[ws.length - 1])) return false
  for (var i = 0; i < ws.length - 1; i++) if (!matches(hay, ws[i])) return false
  return true
}

function score(query, entry) {
  var s = Match.match(query, baseName(entry.rel), "", entry.rel)
  return s ? Math.max(FLOOR, Math.round(s * WEIGHT)) : FLOOR
}

function openEffect(entry) { return { type: "exec", argv: ["xdg-open", entry.path] } }

// A file opens Ghostty in its parent folder. Paths stay literal argv.
function terminalEffect(entry) {
  var dir = entry.dir ? entry.path : entry.path.slice(0, entry.path.lastIndexOf("/"))
  return { type: "exec", argv: ["uwsm-app", "--", "ghostty", "--working-directory=" + dir] }
}

function row(query, entry, order, known) {
  var name = baseName(entry.rel), kind = kindOf(entry)
  var parent = tilde(parentOf(entry.rel))
  return {
    id: entry.rel, title: name, subtitle: parent + (entry.dir ? " · Folder" : ""), icon: ICONS[kind], section: "Files",
    verb: entry.dir ? "Open folder" : "Open", tier: "item", score: known === undefined ? score(query, entry) : known, order: order, remember: true,
    hint: "ctrl ↵ terminal", action: openEffect(entry), altAction: terminalEffect(entry),
    preview: tilde(entry.rel), previewLabel: entry.dir ? "FOLDER" : "FILE", previewImage: kind === "image" ? entry.path : "",
    previewDetail: entry.dir ? "↵ opens in your file manager · Ctrl+↵ opens a terminal here"
                             : "↵ opens with the default app · Ctrl+↵ opens a terminal in " + parent
  }
}

// The best `limit` rows out of fd's candidates. Scoring happens here, on a
// few hundred entries at most, never on the whole tree; only the survivors
// become full rows.
function rows(query, entries, settings, scoped) {
  var ws = words(query), limit = scoped ? SCOPED_LIMIT : settings.limit
  if (!ws.length) return []
  var scored = []
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    if (e.dir ? !settings.folders : !settings.files) continue
    if (!matchesRelative(e, ws, settings.fuzzy)) continue
    scored.push({ entry: e, score: score(query, e), order: i })
  }
  scored.sort(function(a, b) { return b.score - a.score || a.order - b.order })
  var out = []
  for (i = 0; i < scored.length && i < limit; i++) out.push(row(query, scored[i].entry, scored[i].order, scored[i].score))
  return out
}
