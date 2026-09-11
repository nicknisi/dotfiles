.pragma library
.import "Match.js" as Match

// The settings screens as one flat, searchable tree. build() turns the
// palette schema and the provider registry into nodes. The global palette
// exposes only the Settings entry. Inside Settings, rows() lists one screen
// or searches every screen below it, including nested choices.
//
// Scopes: "" (palette root) › settings › settings/palette | settings/<key>
//         › settings/palette/<setting> | settings/<key>/<setting>
// String and number settings own a value screen instead of child nodes;
// build() lists those under `screens` for the provider to render.

var ROOT_TITLE = "Keystroke Settings"
var GEAR = "󰒓"

function titleCase(s) { s = String(s); return s.charAt(0).toUpperCase() + s.slice(1) }
function navigate(scope, title) { return { type: "navigate", scope: scope, title: title } }
function settingAction(path, key, value, schema) { return { type: "setting", path: path, key: key, value: value, schema: schema } }

function node(parentScope, parts, fields) {
  var n = { parentScope: parentScope, parts: parts, path: parts.join(" › "), title: parts[parts.length - 1], subtitle: "", icon: GEAR, iconFont: "", iconSource: "",
            tint: "", section: "Settings", verb: "Open", order: 0, accessory: "", badge: "", keywords: "", description: "", disabled: false,
            lift: 0, listScore: 1, listOnly: false, confirm: "", relative: ({}) }
  for (var k in fields) n[k] = fields[k]
  return n
}

function schemaNodes(nodes, screens, path, schemas, values, scope, parentParts, idPrefix) {
  for (var i = 0; i < schemas.length; i++) {
    var schema = schemas[i], k = schema.key, value = values[k]
    var isBool = schema.type === "boolean", isEnum = schema.type === "enum"
    var parts = parentParts.concat([schema.label])
    var childScope = scope + "/" + k
    var current = isBool ? (value ? "On" : "Off") : (value === "" || value === undefined ? "—" : String(value))
    if (schema.optionLabels && schema.optionLabels[value]) current = schema.optionLabels[value]
    nodes.push(node(scope, parts, { id: idPrefix + "/" + k, subtitle: schema.description || "", verb: isBool ? "Toggle" : "Change", order: i,
      accessory: current, keywords: k + (isEnum ? " " + schema.options.join(" ") : ""), description: schema.description || "",
      action: isBool ? settingAction(path, k, !value, schema) : navigate(childScope, schema.label) }))
    if (isEnum) {
      for (var o = 0; o < schema.options.length; o++) {
        var option = schema.options[o]
        var label = schema.optionLabels && schema.optionLabels[option] ? schema.optionLabels[option] : titleCase(option)
        nodes.push(node(childScope, parts.concat([label]), { id: idPrefix + "/" + k + "/" + option, subtitle: option === value ? "Selected" : "",
          icon: option === value ? "✓" : "○", section: schema.label, verb: "Select", order: o,
          action: settingAction(path, k, option, schema) }))
      }
    } else if (!isBool) screens[childScope] = { path: path, schema: schema, value: value }
  }
}

// The Voice screen (settings/voice): the voxtype integration. Its rows are
// searchable like any setting; the Hyprland bindings row carries a
// confirmation because it edits the user's launcher-voice.lua.
// voice: { schemas, values, detected, version, daemonState,
//          bindings: "installed" | "outdated" | "missing", bindingsPath }
function daemonLabel(voice) {
  var d = String(voice.daemonState || "")
  if (!d) return "daemon not running"
  return d === "idle" ? "daemon ready" : "daemon " + d
}

function voiceNodes(nodes, screens, rootParts, voice) {
  if (!voice) return
  var parts = rootParts.concat(["Voice"])
  var scope = "settings/voice"
  var values = voice.values || {}
  var engine = "Voxtype "
  var on = !!(voice.detected && values.enabled)
  nodes.push(node("settings", parts, { id: "voice", icon: "󰍬", section: "Keystroke", order: 1, lift: 1,
    subtitle: voice.detected ? (on ? "On" : "Off") + " · " + engine + (voice.version || "") + " · " + daemonLabel(voice) : "Voxtype is not installed",
    keywords: "voxtype dictation speech microphone", description: "voice dictation voxtype speech microphone hold to talk transcribe",
    action: navigate(scope, "Voice") }))
  if (!voice.detected) {
    nodes.push(node(scope, parts.concat(["Voxtype is not installed"]), { id: "voice/missing", subtitle: "Voice is optional; Keystroke never installs it in the background",
      icon: "󰀦", verb: "", order: 0, disabled: true, listOnly: true, action: { type: "noop" } }))
    nodes.push(node(scope, parts.concat(["Open voice configuration"]), { id: "voice/configure", subtitle: "Configure the existing voice integration; install voxtype separately if needed",
      icon: "", verb: "Configure", order: 1, keywords: "voxtype configure", description: "configure voxtype dictation",
      action: voice.configurationAction || { type: "edit" } }))
    return
  }
  schemaNodes(nodes, screens, ["voice"], voice.schemas || [], values, scope, parts, "voice")
  var st = String(voice.bindings || "missing")
  var path = String(voice.bindingsPath || "~/.config/hypr/launcher-voice.lua")
  nodes.push(node(scope, parts.concat(["Hold-to-talk bindings"]), { id: "voice/bindings", icon: "󰌌", order: 50,
    verb: st === "installed" ? "Reinstall" : st === "outdated" ? "Update" : "Install",
    subtitle: st === "installed" ? "Long-press and release binds are in " + path
            : st === "outdated" ? "The block in " + path + " does not match the hotkeys above"
            : "Adds long-press and release binds for the hotkeys above to " + path,
    accessory: st === "installed" ? "Installed" : st === "outdated" ? "Outdated" : "Missing",
    keywords: "hyprland bindings hold", description: "hyprland keybinding long press release install launcher-voice.lua",
    confirm: (st === "missing" ? "Add" : "Rewrite") + " the Keystroke voice block in " + path + " and reload Hyprland?",
    action: { type: "voice-bindings" } }))
  nodes.push(node(scope, parts.concat([engine + (voice.version || "")]), { id: "voice/status", icon: "󰍬", verb: "", order: 60, disabled: true, listOnly: true,
    subtitle: daemonLabel(voice) + " · tap the hotkey again or hold it while the palette is open", action: { type: "noop" } }))

}

// model: { configPath, paletteSchema, paletteValues, voice,
//          entries: [{ key, name, description, icon, iconFont, iconSource, color, source, pluginId, enabled, schemas, values }],
//          problems: [{ pluginId, message }] }
function build(model) {
  var nodes = [], screens = ({})
  var rootParts = [ROOT_TITLE]
  nodes.push(node("", rootParts, { id: "settings", subtitle: "Providers, appearance and the config file", order: 7, listScore: 20,
    description: "preferences configuration providers", action: navigate("settings", "Settings") }))
  var appearance = rootParts.concat(["Appearance"])
  nodes.push(node("settings", appearance, { id: "palette", subtitle: "Density, accent, previews and animations", icon: "󰏘", section: "Keystroke", order: 0, lift: 1,
    description: "layout density accent preview theme animations motion transitions", action: navigate("settings/palette", "Appearance") }))
  schemaNodes(nodes, screens, ["palette"], model.paletteSchema || [], model.paletteValues || {}, "settings/palette", appearance, "palette")
  voiceNodes(nodes, screens, rootParts, model.voice)
  if (model.matching) {
    var matching = rootParts.concat(["Matching"])
    nodes.push(node("settings", matching, { id: "matching", section: "Keystroke", order: 2, subtitle: "Smart match and model size",
      keywords: "semantic embeddings search", action: navigate("settings/matching", "Matching") }))
    schemaNodes(nodes, screens, ["matching"], model.matching.schemas, model.matching.values, "settings/matching", matching, "matching")
    nodes.push(node("settings/matching", matching.concat([model.matching.error ? "Retry Smart Match" : model.matching.status || "Model unloaded"]), {
      id: "matching/status", order: 10, listOnly: true, disabled: !model.matching.error,
      subtitle: model.matching.error || "Models are downloaded once and matched locally", verb: model.matching.error ? "Retry" : "",
      action: model.matching.error ? { type: "matching-retry" } : { type: "noop" } }))
  }
  nodes.push(node("settings", rootParts.concat(["Open config file"]), { id: "config", subtitle: String(model.configPath || ""), icon: "", section: "Keystroke",
    verb: "Open file", order: 2, keywords: "json", description: "edit", action: { type: "edit" } }))
  var entries = model.entries || []
  for (var i = 0; i < entries.length; i++) {
    var e = entries[i]
    var parts = rootParts.concat([e.name])
    var scope = "settings/" + e.key
    var community = e.source === "community"
    var origin = community ? "Plugin " + e.pluginId : "Bundled"
    nodes.push(node("settings", parts, { id: e.key, subtitle: (e.enabled ? "Enabled" : "Disabled") + " · " + origin + (e.description ? " · " + e.description : ""),
      icon: e.icon || "⌘", iconFont: e.iconFont || "", iconSource: e.iconSource || "", tint: e.color || "", section: "Providers", order: 10 + i, badge: community ? "plugin" : "",
      keywords: e.key, description: e.description || "", action: navigate(scope, e.name) }))
    var path = ["providers", e.key]
    // Labelled "Enabled" rather than "Enable provider": the row sits on the
    // provider's own screen and its breadcrumb names the provider, and the
    // word "provider" would otherwise shadow settings that carry it as a key.
    var enabledSchema = { key: "enabled", type: "boolean", label: "Enabled",
                          description: community ? "Runs plugin code in your shell with your permissions" : "Include this provider in Keystroke" }
    nodes.push(node(scope, parts.concat([enabledSchema.label]), { id: e.key + "/enabled", subtitle: enabledSchema.description, verb: "Toggle", order: -1, lift: 1,
      accessory: e.enabled ? "On" : "Off", keywords: "enabled", description: "enable disable toggle on off " + enabledSchema.description,
      confirm: community && !e.enabled ? "Enable " + e.name + "? It runs unsandboxed code in your shell with all your permissions." : "",
      action: settingAction(path, "enabled", !e.enabled, enabledSchema) }))
    if (community)
      nodes.push(node(scope, parts.concat(["Manage extension"]), { id: e.key + "/provenance", subtitle: "Plugin " + e.pluginId + " · update, load or remove it",
        icon: "󰏓", verb: "Open", order: 900, badge: "plugin", listOnly: true, keywords: e.pluginId, action: navigate("extensions/" + e.pluginId, e.name) }))
    schemaNodes(nodes, screens, path, e.schemas || [], e.values || {}, scope, parts, e.key)
  }
  var problems = model.problems || []
  for (var p = 0; p < problems.length; p++)
    nodes.push(node("settings", rootParts.concat([problems[p].pluginId]), { id: "problem/" + problems[p].pluginId, subtitle: problems[p].message, icon: "󰀦",
      section: "Plugins needing attention", verb: "", order: 500 + p, disabled: true, badge: "plugin", description: "plugin problem " + problems[p].message,
      action: { type: "noop" } }))
  return { nodes: nodes, screens: screens }
}

function depthOf(scope) { return scope ? scope.split("/").length : 0 }

function within(n, scope) {
  if (!scope) return n.parentScope === ""
  return n.parentScope === scope || n.parentScope.indexOf(scope + "/") === 0
}

// Breadcrumb below the current scope, cached per depth: the same strings go
// to the matcher on every keystroke.
function relativePath(n, depth) {
  var hit = n.relative[depth]
  if (hit === undefined) {
    hit = { path: n.parts.slice(depth).join(" › "), parent: n.parts.slice(depth, -1).join(" › ") }
    n.relative[depth] = hit
  }
  return hit
}

function row(n, score, subtitle, section) {
  return { id: n.id, title: n.title, subtitle: subtitle, icon: n.icon, iconFont: n.iconFont, iconSource: n.iconSource || "", tint: n.tint, section: section, verb: n.verb, tier: "item",
           score: score, order: n.order, accessory: n.accessory, badge: n.badge, disabled: n.disabled, confirm: n.confirm || "", action: n.action, previewDetail: n.path }
}

// Empty query: the screen at `scope`. Otherwise every node at or below it,
// scored on its title, its breadcrumb below the scope and its keywords.
function rows(nodes, scope, query) {
  var out = [], i, n
  var q = String(query || "").trim()
  if (!q) {
    for (i = 0; i < nodes.length; i++) { n = nodes[i]; if (n.parentScope === scope) out.push(row(n, n.listScore, n.subtitle, n.section)) }
    return out
  }
  var depth = depthOf(scope)
  for (i = 0; i < nodes.length; i++) {
    n = nodes[i]
    if (n.listOnly || !within(n, scope)) continue
    var rel = relativePath(n, depth)
    var s = Match.match(q, n.title, n.keywords, rel.parent ? rel.path : "", n.description)
    if (!s) continue
    out.push(row(n, s + n.lift, rel.parent || n.subtitle, "Settings"))
  }
  return out
}

function catalog(tree, scope) {
  if (tree.screens[scope]) return []
  var out = []
  for (var i = 0; i < tree.nodes.length; i++) {
    var n = tree.nodes[i]
    if (n.listOnly || n.disabled || !within(n, scope)) continue
    var r = row(n, 1, n.parts.slice(0, -1).join(" › ") || n.subtitle, "Settings")
    r.path = n.path; r.keywords = n.keywords; r.description = n.description
    out.push(r)
  }
  return out
}
