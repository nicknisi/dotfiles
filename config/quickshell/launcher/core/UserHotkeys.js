.pragma library
.import "Hotkeys.js" as Hotkeys

// Hotkeys assigned from the palette. Ctrl+B on a result records a chord and
// writes one native Hyprland bind per row into the marked block of
// ~/.config/hypr/launcher-hotkeys.lua, which hyprland.lua sources. That file
// is the only store: the palette parses its own lines back to label rows,
// detect conflicts and replace or remove a bind. Every line runs the row
// through `qs ipc call launcher run <provider>/<id>`, so a bind survives an
// app being reinstalled and follows the row's own confirmation.

var BEGIN = "-- >>> keystroke hotkeys: shortcuts set from the palette with Ctrl+B (written by Keystroke, edits inside are replaced)"
var END = "-- <<< keystroke hotkeys"
var RUN = "qs ipc call launcher run "
// Hyprland enters this empty submap while a chord is recorded, so the keys
// reach the palette instead of firing whatever they are bound to.
var SUBMAP = "keystroke-capture"

var ROUTE = /^[A-Za-z0-9_.@+:-]+\/[A-Za-z0-9_.@+:~-]+$/

function lua(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r") + "\"" }
function unlua(s) { return String(s).replace(/\\(.)/g, function(_, c) { return c === "n" ? "\n" : c === "r" ? "\r" : c }) }
function validRoute(route) { return ROUTE.test(String(route || "")) }

// ------------------------------------------------------------------ combos
// The grammar lives in Hotkeys.js, next to the live binds it is compared with.
function parseCombo(text) { return Hotkeys.parseCombo(text) }
function canonical(text) { return Hotkeys.canonical(text) }
function combo(parsed) { return parsed ? parsed.mods.concat([parsed.key]).join(" + ") : "" }
function display(text) {
  var p = parseCombo(text)
  return p ? Hotkeys.keys((p.mods.length ? p.mods.join(" ") + " + " : "") + p.key) : String(text || "")
}
// Modifiers held so far, while the recorder waits for the key.
function displayPartial(text) {
  var mods = String(text || "").split(/[\s+]+/).filter(function(t) { return t })
  return mods.map(function(m) { return Hotkeys.MODIFIERS[m] || m }).concat(["…"]).join(" + ")
}

// A chord needs a real modifier unless the key is a function or media key;
// Shift alone would take over typing.
function validate(parsed) {
  if (!parsed) return "Press a key combination"
  if (parsed.key === "ESCAPE") return "Escape is reserved"
  var standalone = /^F\d{1,2}$/.test(parsed.key) || parsed.key.indexOf("XF86") === 0 || parsed.key === "PRINT" || parsed.key === "PAUSE"
  var strong = parsed.mods.some(function(m) { return m !== "SHIFT" })
  if (!standalone && !strong) return "Add Super, Ctrl or Alt"
  return ""
}

// ----------------------------------------------------------- Qt key events
var SHIFTED = { "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
                "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`" }
var PUNCTUATION = { ",": "COMMA", ".": "PERIOD", "-": "MINUS", "=": "EQUAL", "/": "SLASH", "\\": "BACKSLASH", "`": "GRAVE",
                    "[": "BRACKETLEFT", "]": "BRACKETRIGHT", ";": "SEMICOLON", "'": "APOSTROPHE" }
function keyTable() {
  if (typeof Qt === "undefined") return {}
  var t = {}
  t[Qt.Key_Return] = "RETURN"; t[Qt.Key_Enter] = "RETURN"; t[Qt.Key_Space] = "SPACE"; t[Qt.Key_Tab] = "TAB"; t[Qt.Key_Backtab] = "TAB"
  t[Qt.Key_Backspace] = "BACKSPACE"; t[Qt.Key_Delete] = "DELETE"; t[Qt.Key_Insert] = "INSERT"; t[Qt.Key_Home] = "HOME"; t[Qt.Key_End] = "END"
  t[Qt.Key_PageUp] = "PRIOR"; t[Qt.Key_PageDown] = "NEXT"; t[Qt.Key_Left] = "LEFT"; t[Qt.Key_Right] = "RIGHT"; t[Qt.Key_Up] = "UP"; t[Qt.Key_Down] = "DOWN"
  t[Qt.Key_Print] = "PRINT"; t[Qt.Key_Pause] = "PAUSE"; t[Qt.Key_Menu] = "MENU"; t[Qt.Key_Escape] = "ESCAPE"
  t[Qt.Key_MediaPlay] = "XF86AudioPlay"; t[Qt.Key_MediaTogglePlayPause] = "XF86AudioPlay"; t[Qt.Key_MediaPause] = "XF86AudioPause"
  t[Qt.Key_MediaStop] = "XF86AudioStop"; t[Qt.Key_MediaNext] = "XF86AudioNext"; t[Qt.Key_MediaPrevious] = "XF86AudioPrev"
  t[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"; t[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"; t[Qt.Key_VolumeMute] = "XF86AudioMute"
  t[Qt.Key_MicMute] = "XF86AudioMicMute"; t[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp"; t[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown"
  t[Qt.Key_Calculator] = "XF86Calculator"; t[Qt.Key_HomePage] = "XF86HomePage"; t[Qt.Key_Search] = "XF86Search"; t[Qt.Key_Explorer] = "XF86Explorer"
  t[Qt.Key_LaunchMail] = "XF86Mail"; t[Qt.Key_Favorites] = "XF86Favorites"
  return t
}
var KEY_TABLE = null

// The digit row is bound by keycode, as workspaces.lua does, so the bind
// survives layout changes and matches the config's own spelling.
function digitKey(digit) { return "code:" + (digit === "0" ? 19 : 9 + Number(digit)) }
function keyName(key, text) {
  if (KEY_TABLE === null) KEY_TABLE = keyTable()
  if (KEY_TABLE[key]) return KEY_TABLE[key]
  if (key >= 0x41 && key <= 0x5a) return String.fromCharCode(key)             // Qt.Key_A … Qt.Key_Z
  if (key >= 0x30 && key <= 0x39) return digitKey(String.fromCharCode(key))     // Qt.Key_0 … Qt.Key_9
  if (typeof Qt !== "undefined" && key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1)
  var ch = String(text || "")
  if (ch.length !== 1) ch = key > 0x20 && key < 0x7f ? String.fromCharCode(key) : ""
  if (SHIFTED[ch]) ch = SHIFTED[ch]
  if (/^[0-9]$/.test(ch)) return digitKey(ch)
  if (/^[a-z]$/i.test(ch)) return ch.toUpperCase()
  return PUNCTUATION[ch] || ""
}
function isModifierKey(key) {
  if (typeof Qt === "undefined") return false
  return key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt || key === Qt.Key_AltGr || key === Qt.Key_Meta
    || key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R || key === Qt.Key_CapsLock
}
function modifiersOf(modifiers) {
  var mods = []
  if (typeof Qt === "undefined") return mods
  if (modifiers & Qt.MetaModifier) mods.push("SUPER")
  if (modifiers & Qt.ShiftModifier) mods.push("SHIFT")
  if (modifiers & Qt.ControlModifier) mods.push("CTRL")
  if (modifiers & Qt.AltModifier) mods.push("ALT")
  return mods
}
// { combo } for a bindable chord, { error } otherwise; modifier presses alone
// yield { partial } so the recorder can show what is held.
function chord(key, modifiers, text) {
  var mods = modifiersOf(modifiers)
  if (isModifierKey(key)) return { partial: mods.join(" + ") }
  var name = keyName(key, text)
  if (!name) return { error: "That key can't be bound" }
  var parsed = parseCombo(mods.concat([name]).join(" + "))
  var problem = validate(parsed)
  return problem ? { error: problem, combo: combo(parsed) } : { combo: combo(parsed) }
}

// ------------------------------------------------------------------- file
var LINE = /^hl\.bind\("((?:[^"\\]|\\.)*)", hl\.dsp\.exec_cmd\("qs ipc call launcher run ((?:[^"\\]|\\.)*)"\), \{ description = "((?:[^"\\]|\\.)*)" \}\)$/
function line(entry) {
  return "hl.bind(" + lua(entry.combo) + ", hl.dsp.exec_cmd(" + lua(RUN + entry.route) + "), { description = " + lua(entry.label) + " })"
}
function find(text) {
  var s = String(text || "")
  var a = s.indexOf(BEGIN)
  if (a < 0) return null
  var b = s.indexOf(END, a)
  if (b < 0) return { start: a, end: s.length, body: s.slice(a) }
  return { start: a, end: b + END.length, body: s.slice(a, b + END.length) }
}
// Lines the palette wrote come back as entries; anything else inside the
// block is carried along unchanged so a hand-written bind is not lost.
function parse(text) {
  var hit = find(text), entries = [], foreign = []
  if (!hit) return { entries: entries, foreign: foreign, found: false }
  var lines = hit.body.split("\n")
  for (var i = 1; i < lines.length; i++) {
    var raw = lines[i]
    if (raw === END || !raw.trim()) continue
    var m = LINE.exec(raw)
    var route = m ? unlua(m[2]) : ""
    if (m && validRoute(route) && parseCombo(unlua(m[1]))) entries.push({ combo: combo(parseCombo(unlua(m[1]))), route: route, label: unlua(m[3]) })
    else foreign.push(raw)
  }
  return { entries: entries, foreign: foreign, found: true }
}
function block(entries, foreign) {
  var lines = [BEGIN]
  for (var i = 0; i < (entries || []).length; i++) lines.push(line(entries[i]))
  for (var f = 0; f < (foreign || []).length; f++) lines.push(foreign[f])
  lines.push(END)
  return lines.join("\n")
}
function apply(text, entries, foreign) {
  var s = String(text || "")
  var hit = find(s)
  var fresh = block(entries, foreign)
  if (hit) return s.slice(0, hit.start) + fresh + s.slice(hit.end)
  if (s.length && s.charAt(s.length - 1) !== "\n") s += "\n"
  if (s.length) s += "\n"
  return s + fresh + "\n"
}

// ---------------------------------------------------------------- entries
function forRoute(entries, route) {
  for (var i = 0; i < entries.length; i++) if (entries[i].route === route) return entries[i]
  return null
}
function forCombo(entries, text) {
  var key = canonical(text)
  for (var i = 0; i < entries.length; i++) if (key && canonical(entries[i].combo) === key) return entries[i]
  return null
}
// One chord per row and one row per chord: setting either side replaces the other.
function withBinding(entries, text, route, label) {
  var next = [], key = canonical(text)
  for (var i = 0; i < entries.length; i++)
    if (entries[i].route !== route && canonical(entries[i].combo) !== key) next.push(entries[i])
  next.push({ combo: combo(parseCombo(text)), route: route, label: String(label || route) })
  return next
}
function withoutRoute(entries, route) { return entries.filter(function(e) { return e.route !== route }) }
function byRoute(entries) {
  var out = ({})
  for (var i = 0; i < entries.length; i++) out[entries[i].route] = entries[i]
  return out
}

// What Enter would do for `text` on `route`. Live binds are the Hotkeys
// provider's parsed records; a live bind whose chord is one of ours is not a
// conflict, it is the bind being replaced.
function check(text, route, entries, liveBinds) {
  var parsed = parseCombo(text), problem = validate(parsed)
  if (problem) return { state: "invalid", message: problem }
  var key = canonical(text)
  var own = forCombo(entries, text), current = forRoute(entries, route)
  if (own && own.route === route) return { state: "same", message: "Already " + display(text) }
  for (var i = 0; !own && i < (liveBinds || []).length; i++) {
    var bind = liveBinds[i]
    if (bind.submap) continue
    for (var c = 0; c < bind.combos.length; c++)
      if (canonical(bind.combos[c]) === key) return { state: "taken", message: "Taken by " + bind.label + " in your Hyprland config" }
  }
  if (own) return { state: "replace", message: "Replaces " + own.label + "'s hotkey" + (current ? " · moves from " + display(current.combo) : "") }
  if (current) return { state: "move", message: "Moves from " + display(current.combo) }
  return { state: "available", message: "Available" }
}
