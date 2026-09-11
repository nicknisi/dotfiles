.pragma library

// Native Hyprland bindings for hold-to-dictate. They live in the dedicated
// ~/.config/hypr/launcher-voice.lua inside a marked block that
// Keystroke Settings › Voice writes and rewrites; everything outside the
// markers is left alone.
//
// Hyprland fires a long-press bind (`o`) once the key has been down for the
// keyboard repeat delay. Universal, non-consuming release bindings ignore
// modifiers and cover the chord's modifiers too, so either release order
// stops recording even if the palette no longer has keyboard focus.

var BEGIN = "-- >>> keystroke voice: hold the palette hotkey to dictate (written by Keystroke Settings › Voice)"
var END = "-- <<< keystroke voice"
var HOLD = "qs ipc call launcher voiceHold"
var RELEASE = "qs ipc call launcher voiceRelease"

function parseKeys(text) {
  var out = [], parts = String(text || "").split(",")
  for (var i = 0; i < parts.length; i++) {
    var k = parts[i].trim().replace(/\s+/g, " ")
    if (k && out.indexOf(k) < 0) out.push(k)
  }
  return out
}

function lua(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r") + "\"" }

function block(keys) {
  var lines = [BEGIN]
  var combos = parseKeys(Array.isArray(keys) ? keys.join(",") : keys)
  var releases = [], modifiers = { SUPER: ["Super_L", "Super_R"], MOD4: ["Super_L", "Super_R"],
    SHIFT: ["Shift_L", "Shift_R"], CTRL: ["Control_L", "Control_R"], CONTROL: ["Control_L", "Control_R"],
    ALT: ["Alt_L", "Alt_R"], MOD1: ["Alt_L", "Alt_R"] }
  for (var i = 0; i < combos.length; i++) {
    lines.push("hl.bind(" + lua(combos[i]) + ", hl.dsp.exec_cmd(" + lua(HOLD) + "), { long_press = true })")
    var parts = combos[i].split(/\s*\+\s*/), key = parts.pop()
    releases.push(key)
    for (var j = 0; j < parts.length; j++) releases = releases.concat(modifiers[parts[j].toUpperCase()] || [])
  }
  releases.filter((key, index) => releases.indexOf(key) === index).forEach(function(key) {
    lines.push("hl.bind(" + lua(key) + ", hl.dsp.exec_cmd(" + lua(RELEASE) + "), { release = true, ignore_mods = true, submap_universal = true, non_consuming = true })")
  })
  lines.push(END)
  return lines.join("\n")
}

function find(text) {
  var s = String(text || "")
  var a = s.indexOf(BEGIN)
  if (a < 0) return null
  var b = s.indexOf(END, a)
  if (b < 0) return { start: a, end: s.length, body: s.slice(a) }
  var end = b + END.length
  return { start: a, end: end, body: s.slice(a, end) }
}

// "missing" | "outdated" | "installed"
function status(text, keys) {
  var hit = find(text)
  if (!hit) return "missing"
  return hit.body === block(keys) ? "installed" : "outdated"
}

function apply(text, keys) {
  var s = String(text || "")
  var hit = find(s)
  var fresh = block(keys)
  if (hit) return s.slice(0, hit.start) + fresh + s.slice(hit.end)
  if (s.length && s.charAt(s.length - 1) !== "\n") s += "\n"
  if (s.length) s += "\n"
  return s + fresh + "\n"
}

function remove(text) {
  var s = String(text || "")
  var hit = find(s)
  if (!hit) return s
  var before = s.slice(0, hit.start).replace(/\n+$/, "\n")
  var after = s.slice(hit.end).replace(/^\n+/, "")
  return before + after
}
