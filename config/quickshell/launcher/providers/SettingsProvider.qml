import QtQuick
import "../core/Settings.js" as Settings
import "../core/SettingsTree.js" as SettingsTree
import "../core/Extensions.js" as Extensions

// Schema-generated settings screens for the palette and every provider, kept
// as one searchable tree (core/SettingsTree.js). Individual settings and
// choices are searchable only inside Settings, not alongside launcher actions.
// Scopes: settings | settings/palette | settings/<key> | settings/<key>/<setting>
Item {
  id: root
  property var host: null
  property var tree: null
  property var treeStamp: []

  readonly property var provider: ({
    apiVersion: 1,
    id: "settings",
    name: "Keystroke Settings",
    icon: "󰒓",
    color: "#a5a4ad",
    description: "Providers, appearance and the config file",
    settings: [],
    query: function(ctx) { return root.query(ctx) },
    catalog: function(ctx) { return SettingsTree.catalog(root.current(), ctx.scope) },
  })

  function model() {
    var h = root.host, entries = h.registry.entries, out = [], seen = ({})
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      if (e.key === "settings") continue
      seen[e.key] = true
      var schemas = e.provider.settings || []
      out.push({ key: e.key, name: e.provider.name, description: e.provider.description || "", icon: e.provider.icon || "", iconFont: e.provider.iconFont || "",
                 iconSource: e.provider.iconSource || "", color: e.provider.color || "", source: e.source, pluginId: e.pluginId || "", enabled: h.providerEnabled(e), schemas: schemas,
                 values: Settings.values(h.config, ["providers", e.key], schemas) })
    }
    // Disabled services are not instantiated, but their validated metadata
    // still supplies searchable enable/manage rows. Schemas come from code
    // only after the user enables the provider.
    var manifests = h.registry.manifests || {}
    for (var id in manifests) {
      if (seen[id]) continue
      var m = manifests[id]
      out.push({ key: id, name: Extensions.safeString(m.name, 80) || id,
                 description: (Extensions.safeString(m.description, 300) + " · Enable to load provider settings").trim(),
                 source: "community", pluginId: id, enabled: Settings.isEnabled(h.config, ["providers", id], false), schemas: [], values: {} })
    }
    return { configPath: h.configPath, paletteSchema: h.paletteSchema, paletteValues: h.paletteValues(), voice: h.voiceModel(), matching: h.matchingModel(), entries: out, problems: h.registry.problems }
  }

  // Rebuilt only when the config or the registry changes; every keystroke
  // reuses the same nodes and breadcrumb strings.
  function current() {
    var h = root.host
    var stamp = [h.config, h.registry.entries, h.registry.problems, h.voiceStamp, h.matchingStamp, h.registry.manifests]
    var old = root.treeStamp
    if (root.tree && old.length === 6 && old[0] === stamp[0] && old[1] === stamp[1] && old[2] === stamp[2] && old[3] === stamp[3] && old[4] === stamp[4] && old[5] === stamp[5]) return root.tree
    root.tree = SettingsTree.build(root.model())
    root.treeStamp = stamp
    return root.tree
  }

  // String and number settings: the query is the new value.
  function valueRows(ctx, screen) {
    var schema = screen.schema, value = screen.value
    var typed = schema.type === "number" ? Number(ctx.query) : ctx.query
    var ok = ctx.query.length > 0
    try { Settings.validate(schema, typed) } catch (e) { ok = false }
    var rows = [{ id: "current", title: value === "" || value === undefined ? "Not set" : String(value), subtitle: "Current value · type a new one",
                  icon: "󰒓", section: schema.label, verb: "", tier: "item", score: 1, order: 0, disabled: true, action: { type: "noop" } }]
    if (ok) rows.push({ id: "save", title: "Save “" + String(typed) + "”", subtitle: schema.description || "", icon: "✓", section: schema.label,
                        verb: "Save", tier: "item", score: 100, order: 1, action: SettingsTree.settingAction(screen.path, schema.key, typed, schema) })
    return rows
  }

  function query(ctx) {
    if (ctx.scope && ctx.scope.split("/")[0] !== "settings") return []
    if (!root.host) return []
    var t = root.current()
    var screen = ctx.scope ? t.screens[ctx.scope] : null
    if (screen) return root.valueRows(ctx, screen)
    return SettingsTree.rows(t.nodes, ctx.scope, ctx.query)
  }
}
