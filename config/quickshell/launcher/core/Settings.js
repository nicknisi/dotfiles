.pragma library

// Schema-driven settings over one JSON document:
//   { version: 1, palette: {...}, providers: { "<id>": { enabled, ... } } }
// Unknown fields are preserved; invalid values fall back to defaults; a
// document that does not parse is reported and never overwritten.

function empty() {
  return { version: 1, palette: {}, providers: {} }
}

function parse(text) {
  var raw = String(text || "")
  if (!raw.trim()) return { config: empty(), error: "" }
  try {
    var data = JSON.parse(raw)
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("expected an object")
    if (data.version !== 1) throw new Error("expected version: 1")
    if (data.palette !== undefined && (typeof data.palette !== "object" || data.palette === null)) throw new Error("palette must be an object")
    if (data.providers !== undefined && (typeof data.providers !== "object" || data.providers === null)) throw new Error("providers must be an object")
    return { config: data, error: "" }
  } catch (e) {
    return { config: null, error: "Config kept at last valid version: " + e.message }
  }
}

function serialize(config) {
  return JSON.stringify(config, null, 2) + "\n"
}

function validate(schema, value) {
  var kind = schema.type
  var ok = false
  if (kind === "boolean") ok = typeof value === "boolean"
  else if (kind === "string") ok = typeof value === "string" && value.length <= 4096
  else if (kind === "number") {
    var min = schema.min === undefined ? -1e9 : schema.min
    var max = schema.max === undefined ? 1e9 : schema.max
    ok = typeof value === "number" && isFinite(value) && value >= min && value <= max
      && (!schema.integer || Math.floor(value) === value)
  } else if (kind === "enum") ok = Array.isArray(schema.options) && schema.options.indexOf(value) !== -1
  if (!ok) throw new Error("Invalid value for " + schema.key)
}

function section(config, path) {
  var node = config || {}
  for (var i = 0; i < path.length; i++) {
    node = node[path[i]]
    if (!node || typeof node !== "object") return {}
  }
  return node
}

function values(config, path, schemas) {
  var saved = section(config, path)
  var out = {}
  for (var i = 0; i < (schemas || []).length; i++) {
    var s = schemas[i]
    out[s.key] = s["default"]
    if (saved[s.key] !== undefined) {
      try { validate(s, saved[s.key]); out[s.key] = saved[s.key] } catch (e) { }
    }
  }
  return out
}

function isEnabled(config, path, fallback) {
  var saved = section(config, path)
  return typeof saved.enabled === "boolean" ? saved.enabled : fallback
}

function withValue(config, path, key, value, schema) {
  validate(schema || { key: key, type: "boolean" }, value)
  var next = JSON.parse(JSON.stringify(config || empty()))
  next.version = 1
  var node = next
  for (var i = 0; i < path.length; i++) {
    if (!node[path[i]] || typeof node[path[i]] !== "object") node[path[i]] = {}
    node = node[path[i]]
  }
  node[key] = value
  return next
}
