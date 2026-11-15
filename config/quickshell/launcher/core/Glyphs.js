.pragma library

// The Kit/IconPaths.js name a result row's tile draws (launcher-pickers 4.2),
// from the row itself: providers keep their Nerd Font `icon` for older hosts,
// and the island draws Lucide strokes instead. A row may name its own with
// `glyph`. "" means the tile shows the row's `icon` text as it is (an emoji,
// a dmenu option's own glyph); apps show their desktop icon over it.

var BY_PROVIDER = {
  applications: "window", files: "file", clipboard: "clip", emoji: "smile", calculator: "calculator",
  converter: "convert", timer: "timer", colors: "palette", codex: "sparkle", ai: "globe",
  settings: "settings", extensions: "puzzle", hotkeys: "keyboard", dictation: "mic", dmenu: "command"
}

// System rows by id (Session, Capture, Themes, ...) or by the menu they sit in.
var SYSTEM = {
  session: "power", capture: "crop", theme: "palette", backgrounds: "image", audio: "vol", net: "wifi",
  bt: "bt", display: "monitor", tailscale: "tailscale", bar: "sliders",
  "action-lock": "lock", "action-suspend": "moon", "action-logout": "logout", "action-reboot": "restart",
  "action-poweroff": "power", "action-record-region": "record", "action-record-window": "record",
  "action-record-screen": "record", "action-record-stop": "record", "action-screenshot-annotate": "pen",
  // Main board: crop, window, monitor and pen for the four capture rows.
  "action-screenshot-region": "crop", "action-screenshot-window": "window", "action-screenshot-screen": "monitor",
  "wallpaper-next": "image", "wallpaper-picker": "image",
  // Open Control center (the voice board's row, `sliders`).
  "control-center": "sliders"
}

function forRow(row) {
  if (!row) return "command"
  if (row.glyph !== undefined && row.glyph !== null) return String(row.glyph)
  var key = String(row.providerKey || "")
  if (key === "emoji" && row.emoji === true) return ""
  if (key === "dmenu") return row.icon ? "" : "command"
  if (key === "files") return /Folder$/.test(String(row.subtitle || "")) || row.previewLabel === "FOLDER" ? "folder" : "file"
  if (key === "colors") return row.id === "picker" ? "pipette" : "palette"
  if (key === "system") {
    var id = String(row.id || "")
    if (SYSTEM[id]) return SYSTEM[id]
    if (SYSTEM[row.parent]) return SYSTEM[row.parent]
    return "sliders"
  }
  return BY_PROVIDER[key] || "command"
}
