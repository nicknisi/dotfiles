.pragma library
.import "Match.js" as Match

// Native API 1 community providers. The LuaJIT helper validates managed
// installations before the registry can load code. This module owns argv,
// parsing and rows, while Extensions.qml owns jobs and Registry.qml services.
//
// Scopes: extensions (the screen) › extensions/<plugin id> (one extension)

var KEY = "extensions"
var ICON = "󰏓"
// Empty means the shipped index. Remote indexes are an explicit setting.
var INDEX_URL = ""
var MARKER = "x-keystroke"

function navigate(scope, title) { return { type: "navigate", scope: scope, title: title } }
function op(name, fields) { var a = { type: "ext", op: name }; for (var k in fields || {}) a[k] = fields[k]; return a }

function safeString(v, limit) { return String(v === undefined || v === null ? "" : v).replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, limit || 400) }

// No shell, SSH, credentials, helper protocols or option-shaped URLs.
// The helper repeats validation, including decoded paths and local symlinks.
function gitUrl(text) {
  var raw = String(text || "")
  if (/[\u0000-\u001f\u007f]/.test(raw)) return ""
  var t = raw.trim(), decoded
  try { decoded = decodeURIComponent(t) } catch (e) { return "" }
  if (!t || t.length > 2048 || t.charAt(0) === "-" || /[\s\\?#]/.test(t) || /[\u0000-\u001f\u007f\\]/.test(decoded)) return ""
  if (/(?:^|\/)\.{1,2}(?:\/|$)/.test(decoded)) return ""
  if (/^https:\/\/[A-Za-z0-9][A-Za-z0-9.-]*(?::[0-9]{1,5})?\/[^\s]+$/.test(t)) return t
  if (/^file:\/\/\/[^/][^\s]*$/.test(t)) return t
  if (/^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9][A-Za-z0-9._-]*$/.test(t)) return "https://github.com/" + t.replace(/\.git$/, "") + ".git"
  return ""
}

function validId(id) { return typeof id === "string" && id.length <= 120 && /^[a-z0-9][a-z0-9_-]*(?:\.[a-z0-9][a-z0-9_-]*)+$/.test(id) }

function repoSlug(url) {
  var m = /github\.com[:\/]([^\/\s]+\/[^\/\s]+?)(?:\.git)?\/?$/.exec(String(url || ""))
  return m ? m[1].toLowerCase() : String(url || "").toLowerCase()
}

// The Keystroke index: { version: 1, extensions: [ { id, name, description, author, repo, tags } ] }
function parseIndex(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return [] }
  if (!data || data.version !== 1 || !Array.isArray(data.extensions)) return []
  var out = []
  for (var i = 0; i < data.extensions.length; i++) {
    var e = data.extensions[i]
    if (!e || typeof e !== "object") continue
    var id = safeString(e.id, 120).toLowerCase(), repo = gitUrl(e.repo)
    if (!validId(id) || !repo) continue
    out.push({ id: id, name: safeString(e.name, 80) || id, description: safeString(e.description, 300), author: safeString(e.author, 80),
               repo: repo, tags: Array.isArray(e.tags) ? e.tags.map(function(t) { return safeString(t, 30) }).filter(Boolean) : [], source: "index" })
  }
  return out
}

// A single index, deduplicated by manifest ID and repository.
function discover(indexEntries) {
  var out = [], seenId = ({}), seenRepo = ({})
  var all = indexEntries || []
  for (var i = 0; i < all.length; i++) {
    var e = all[i], slug = repoSlug(e.repo)
    if (seenId[e.id] || seenRepo[slug]) continue
    seenId[e.id] = true; seenRepo[slug] = true
    out.push(e)
  }
  return out
}

// Installed extensions: every folder under the plugins directory whose
// manifest carries the marker, as the scan found them (parseScan).
// enabledIn(id): Keystroke's switch (keystroke.json); problems: the
// registry's [{ pluginId, message }], the first of which per id is shown;
// git: { id: { head, remote, remoteHead } } from the last update check.
function installed(manifests, enabledIn, git, problems) {
  var trouble = ({})
  for (var p = 0; p < (problems || []).length; p++)
    if (problems[p] && !trouble[problems[p].pluginId]) trouble[problems[p].pluginId] = safeString(problems[p].message, 300)
  var out = []
  for (var id in manifests || {}) {
    var m = manifests[id]
    if (!m || typeof m !== "object" || !m[MARKER] || typeof m[MARKER] !== "object") continue
    var g = git && git[id] ? git[id] : null
    out.push({ id: id, name: safeString(m.name, 80) || id, version: safeString(m.version, 64), description: safeString(m.description, 300),
               author: safeString(m.author, 80), homepage: /^https:\/\//.test(String(m.homepage || "")) ? gitUrl(m.homepage) : "", apiVersion: m[MARKER].apiVersion,
               enabled: enabledIn ? !!enabledIn(id) : false, problem: trouble[id] || "",
               git: g ? g.git !== false : m.__git === true, remote: g ? g.remote : "", checked: !!(g && g.fetched),
               updateAvailable: !!(g && g.head && g.remoteHead && g.head !== g.remoteHead) })
  }
  out.sort(function(a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 })
  return out
}

// Fields a loaded provider adds to its installed entry: its own glyph, image
// icon and accent replace the generic extension icon on every row about it,
// and the examples of its declared patterns become a line of the About section.
function decorate(e, provider, examples) {
  if (!provider || typeof provider !== "object") return e
  e.icon = safeString(provider.icon, 8)
  e.iconFont = safeString(provider.iconFont, 80)
  e.iconSource = safeString(provider.iconSource, 1024)
  e.tint = safeString(provider.color, 32)
  e.examples = Array.isArray(examples) ? examples.slice(0, 6) : []
  return e
}
function iconOf(e) { return { icon: e.icon || ICON, iconFont: e.iconFont || "", iconSource: e.iconSource || "", tint: e.tint || "" } }

// ------------------------------------------------------------------ commands

function pluginsDir(home, dataHome) { return (dataHome || home + "/.local/share") + "/keystroke/extensions" }
function helperArgv(rootDir) {
  if (typeof rootDir !== "string" || rootDir.charAt(0) !== "/" || rootDir.split("/").indexOf("..") >= 0) throw new Error("Absolute launcher rootDir is required")
  return ["luajit", rootDir + "/helpers/extensions.lua"]
}
function installArgv(rootDir, url, id) { return helperArgv(rootDir).concat(["install", "--id", id || "", "--", url]) }
function updateArgv(rootDir, id) { return helperArgv(rootDir).concat(["update", "--", id]) }
// QML caches component URLs. Never claim that an updated service is new code.
function updatedText(name) { return "Updated " + name + " · restart the launcher shell to load its new code" }
function removeArgv(rootDir, id) { return helperArgv(rootDir).concat(["remove", "--", id]) }
function checkArgv(rootDir, ids) { return helperArgv(rootDir).concat(["check", "--"], ids || []) }

// All installations have validated metadata for management. Only explicitly
// enabled IDs receive __sourceDir. The helper strips stamps from disk first.
function enabledIds(config) {
  var providers = config && config.providers || {}, out = []
  for (var id in providers) if (validId(id) && providers[id] && providers[id].enabled === true) out.push(id)
  return out.sort()
}
function scanArgv(rootDir, ids) { return helperArgv(rootDir).concat(["scan", "--enabled-json", JSON.stringify(ids || [])]) }
function parseScan(text) {
  var manifests = ({}), problems = [], data
  try { data = JSON.parse(String(text || "")) } catch (e) { return { manifests: manifests, problems: [{ pluginId: KEY, message: "Extension scan did not return valid JSON" }] } }
  if (!data || !data.manifests || typeof data.manifests !== "object" || Array.isArray(data.manifests))
    return { manifests: manifests, problems: [{ pluginId: KEY, message: "Invalid extension scan" }] }
  if (Array.isArray(data.problems)) problems = data.problems.filter(function(p) { return p && typeof p === "object" }).map(function(p) { return { pluginId: safeString(p.pluginId, 120), message: safeString(p.message, 300) } })
  for (var id in data.manifests) {
    var m = data.manifests[id]
    if (!validId(id) || !m || m.id !== id || m.__validated !== true || !m[MARKER] || m[MARKER].apiVersion !== 1) {
      problems.push({ pluginId: id, message: "Unvalidated extension manifest" }); continue
    }
    if (m.__enabled !== true) delete m.__sourceDir
    else if (!serviceUrl(m)) { problems.push({ pluginId: id, message: "Invalid service entry point" }); continue }
    manifests[id] = m
  }
  return { manifests: manifests, problems: problems }
}

// Only helper-validated, enabled installations are loadable. Encode path
// segments so filesystem names cannot change file URL query/fragment semantics.
function serviceUrl(manifest) {
  if (!manifest || manifest.__validated !== true || manifest.__enabled !== true || !validId(manifest.id) || !manifest[MARKER] || manifest[MARKER].apiVersion !== 1) return ""
  var dir = manifest.__sourceDir, kinds = Array.isArray(manifest.kinds) ? manifest.kinds : []
  var ep = manifest.entryPoints && manifest.entryPoints.service
  if (typeof dir !== "string" || dir.charAt(0) !== "/" || /[\u0000-\u001f\u007f\\]/.test(dir) || dir.split("/").some(function(p) { return p === "." || p === ".." })) return ""
  var suffix = "/keystroke/extensions/" + manifest.id
  if (dir.slice(-suffix.length) !== suffix || kinds.indexOf("service") < 0 || typeof ep !== "string" || !/\.qml$/.test(ep)) return ""
  if (!ep.split("/").every(function(p) { return /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/.test(p) })) return ""
  return "file://" + (dir + "/" + ep).split("/").map(encodeURIComponent).join("/")
}

// The manifest an extension sees: its own file, without the host's stamps.
function publicManifest(manifest) {
  var copy = JSON.parse(JSON.stringify(manifest || {}))
  for (var k in copy) if (k.indexOf("__") === 0) delete copy[k]
  return copy
}

function parseCheck(text) {
  var out = ({}), lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    if (parts.length < 4 || !validId(parts[0])) continue
    out[parts[0]] = { git: !!parts[1], head: parts[1], remoteHead: parts[2], remote: parts[3], fetched: !!parts[2] }
  }
  return out
}

// The native helper reports the validated installed identity.
function parseAdded(output) {
  var m = /(?:^|\n)Added (\S+) into /.exec(String(output || ""))
  return m && validId(m[1]) ? m[1] : ""
}

function fetchArgv(url) { return ["curl", "-q", "-fsS", "--proto", "=https,file", "--max-time", "20", "--max-filesize", "1048576", "--", url] }

// Persistent jobs use atomic JSON files, not shell scripts. The helper only
// dispatches its own fixed operations. Acknowledgment prevents replaying an
// install's enable decision when the palette is recreated later.
function jobArgv(dir, job, rootDir, argv) {
  var helper = helperArgv(rootDir)
  if (argv[0] !== helper[0] || argv[1] !== helper[1]) throw new Error("Invalid extension job command")
  return helper.concat(["job", dir, JSON.stringify(job), "--"], argv.slice(2))
}
function ackArgv(rootDir, startedAt) { return helperArgv(rootDir).concat(["ack", String(startedAt)]) }

function parseResult(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!data || typeof data !== "object" || !data.job || typeof data.job !== "object" || typeof data.job.startedAt !== "number" || !isFinite(Number(data.code))) return null
  return { job: data.job, code: Number(data.code), output: String(data.output || "") }
}

// ---------------------------------------------------------------------- rows

function navRow(score) {
  return { id: "open", title: "Extensions", subtitle: "Install, update and manage community providers", icon: ICON, section: "Keystroke",
           verb: "Open", tier: "item", score: score, order: 8, keywords: "plugins store marketplace community install",
           description: "extensions plugins store marketplace community providers install update", action: navigate(KEY, "Extensions") }
}

// Keystroke's switch is a plain setting effect; the host writes it and requeries.
function enableEffect(id, value) {
  return { type: "setting", path: ["providers", id], key: "enabled", value: !!value, schema: { key: "enabled", type: "boolean" } }
}

function stateText(e) {
  if (e.problem) return "Needs attention"
  return e.enabled ? "On" : "Off"
}

function enableConfirm(e) { return e.enabled ? "" : "Enable " + e.name + "? It runs unsandboxed code in your shell with all your permissions." }

function installedRow(e, scoped) {
  var state = e.updateAvailable ? "Update available" : stateText(e)
  var sub = (e.version ? "v" + e.version + " · " : "") + (e.problem ? e.problem : e.enabled ? "Enabled" : "Off in Keystroke") + " · " + e.id
  var ic = iconOf(e)
  return { id: "installed/" + e.id, title: e.name, subtitle: sub, icon: ic.icon, iconFont: ic.iconFont, iconSource: ic.iconSource, tint: ic.tint,
           section: "Installed", verb: "Open", tier: "item", order: 0,
           accessory: state, keywords: e.id, description: e.description, badge: "plugin", path: scoped ? "" : "Extensions › " + e.name,
           action: navigate(KEY + "/" + e.id, e.name), altAction: enableEffect(e.id, !e.enabled), altConfirm: enableConfirm(e),
           hint: e.enabled ? "ctrl ↵ turn off" : "ctrl ↵ turn on" }
}

function discoverRow(e, order) {
  return { id: "discover/" + e.id, title: e.name, subtitle: (e.author ? e.author + " · " : "") + repoSlug(e.repo), icon: "", section: "Discover",
           verb: "Install", tier: "item", order: order, badge: "index", keywords: e.id + " " + e.tags.join(" "),
           description: e.description, preview: e.description || e.name, previewLabel: "EXTENSION", previewDetail: e.repo,
           confirm: "Install and enable " + e.name + " from " + e.repo + "? It runs unsandboxed code in your shell with all your permissions.",
           action: op("install", { id: e.id, name: e.name, url: e.repo }), altAction: { type: "url", url: e.repo }, hint: "ctrl ↵ repository" }
}

function urlRow(url) {
  return { id: "install-url", title: "Install from " + url, subtitle: "Clones and validates the extension, then explicitly enables it", icon: "",
           section: "Install", verb: "Install", tier: "answer", score: 100, order: 0,
           confirm: "Install and enable an extension from " + url + "? It runs unsandboxed code in your shell with all your permissions.",
           action: op("install", { id: "", name: url, url: url }) }
}

function jobRow(job) {
  return { id: "job", title: job.label, subtitle: job.detail || "Working…", icon: "", section: "Working", verb: "", tier: "answer", score: 200, order: -10,
           disabled: true, action: { type: "noop" } }
}

// The Extensions screen. state: { installed, discover, job, fetching, checked, error }
function screenRows(query, state) {
  var q = String(query || "").trim(), rows = [], i
  if (state.job) rows.push(jobRow(state.job))
  var url = q ? gitUrl(q) : ""
  if (url && q.indexOf("/") > 0) rows.push(urlRow(url))
  var inst = state.installed || [], disc = state.discover || []
  var installedIds = ({})
  for (i = 0; i < inst.length; i++) { installedIds[inst[i].id] = true; rows.push(installedRow(inst[i], true)) }
  if (!q && !inst.length)
    rows.push({ id: "none", title: "No extensions installed", subtitle: "Pick one below, or type a git URL such as owner/repo", icon: ICON, section: "Installed",
                verb: "", tier: "item", score: 1, order: 0, disabled: true, action: { type: "noop" } })
  var updates = 0
  for (i = 0; i < inst.length; i++) if (inst[i].updateAvailable) updates++
  rows.push({ id: "check", title: updates ? "Update all (" + updates + ")" : "Check for updates", subtitle: state.checked ? "Checked " + state.checked : "Checks each repository's default branch without changing your checkout",
              icon: "", section: "Actions", verb: "Run", tier: "item", order: 1, keywords: "update upgrade check fetch", description: "update upgrade refresh check",
              action: updates ? op("update-all") : op("check") })
  rows.push({ id: "refresh", title: "Refresh catalog", subtitle: state.fetching ? "Fetching…" : (state.error ? state.error : "Keystroke extension index"),
              icon: "", section: "Actions", verb: "Run", tier: "item", order: 2, keywords: "refresh reload catalog index marketplace", description: "refresh reload catalog index marketplace",
              action: op("refresh") })
  var n = 0
  for (i = 0; i < disc.length; i++) {
    if (installedIds[disc[i].id]) continue
    rows.push(discoverRow(disc[i], 10 + n++))
  }
  if (!q) for (i = 0; i < rows.length; i++) if (rows[i].score === undefined) rows[i].score = 1
  return rows
}

// One extension's screen.
function detailRows(query, e, state) {
  var rows = []
  if (state && state.job && state.job.id === e.id) rows.push(jobRow(state.job))
  rows.push({ id: e.id + "/enabled", title: "Enabled", subtitle: "Include this extension's results in Keystroke",
              icon: "", section: e.name, verb: "Toggle", tier: "item", order: 0, accessory: e.enabled ? "On" : "Off", keywords: "enable disable on off",
              confirm: enableConfirm(e), action: enableEffect(e.id, !e.enabled) })
  if (e.problem)
    rows.push({ id: e.id + "/problem", title: "Needs attention", subtitle: e.problem, icon: "󰀦", section: e.name, verb: "", tier: "item", order: 1,
                disabled: true, keywords: "problem error attention", action: { type: "noop" } })
  rows.push({ id: e.id + "/settings", title: "Settings", subtitle: "Keystroke Settings › " + e.name, icon: "󰒓", section: e.name, verb: "Open", tier: "item", order: 2,
              action: navigate("settings/" + e.id, e.name) })
  if (e.git) {
    rows.push({ id: e.id + "/update", title: e.updateAvailable ? "Update now" : "Check for updates",
                subtitle: e.updateAvailable ? "Validates a clean fast-forward update, then requires a launcher shell restart" : (e.remote || "Git-managed"),
                icon: "", section: e.name, verb: "Run", tier: "item", order: 3, accessory: e.updateAvailable ? "Update available" : "",
                keywords: "update upgrade check", action: e.updateAvailable ? op("update", { id: e.id, name: e.name }) : op("check", { id: e.id }) })
  } else {
    rows.push({ id: e.id + "/local", title: "Not git-managed", subtitle: "Copied by hand; update it by replacing the folder", icon: "", section: e.name,
                verb: "", tier: "item", order: 3, disabled: true, action: { type: "noop" } })
  }
  if (e.homepage || e.remote)
    rows.push({ id: e.id + "/repo", title: "Open repository", subtitle: e.homepage || e.remote, icon: "", section: e.name, verb: "Open", tier: "item", order: 4,
                keywords: "repository github source homepage", action: { type: "url", url: e.homepage || e.remote } })
  rows.push({ id: e.id + "/remove", title: "Remove", subtitle: "Stops the extension and deletes " + e.id + " from $XDG_DATA_HOME/keystroke/extensions", icon: "󰆴", section: e.name,
              verb: "Remove", tier: "item", order: 9, keywords: "remove uninstall delete",
              confirm: "Remove " + e.name + "? Its Keystroke settings stay in keystroke.json.", action: op("remove", { id: e.id, name: e.name }) })
  var ic = iconOf(e)
  rows.push({ id: e.id + "/about", title: e.name + (e.version ? " v" + e.version : ""), subtitle: [e.author, e.description].filter(Boolean).join(" · ") || e.id,
              icon: ic.icon, iconFont: ic.iconFont, iconSource: ic.iconSource, tint: ic.tint,
              section: "About", verb: "", tier: "item", order: 20, disabled: true, badge: "plugin", action: { type: "noop" } })
  if (e.examples && e.examples.length)
    rows.push({ id: e.id + "/patterns", title: "Answers queries like " + e.examples.join(" · "), subtitle: "Declared patterns lift this extension's results when a query matches",
                icon: "", section: "About", verb: "", tier: "item", order: 21, disabled: true, keywords: "patterns examples", action: { type: "noop" } })
  var q = String(query || "").trim()
  if (!q) for (var i = 0; i < rows.length; i++) if (rows[i].score === undefined) rows[i].score = 1
  return rows
}

function scopeId(scope) {
  var s = String(scope || "")
  if (s === KEY) return ""
  return s.indexOf(KEY + "/") === 0 ? s.slice(KEY.length + 1) : null
}
