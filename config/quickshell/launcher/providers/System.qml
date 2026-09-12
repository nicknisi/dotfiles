import QtQuick
import Quickshell
import Quickshell.Io
import "../.." as Desktop
import "../core/Match.js" as Match

// Native desktop commands and the existing bar's device menus. Keep this the
// first bundled provider: the host delegates IPC routes and reload() here.
Item {
  id: root
  property var host: null
  property string activePage: "audio"
  property var themes: []
  property var backgrounds: []
  property bool themesLoaded: false
  property bool backgroundsLoaded: false
  property string loadError: ""

  readonly property var provider: ({
    apiVersion: 1, id: "system", name: "Desktop", icon: "󰒓", color: "#d4a774",
    description: "Session, capture, themes, wallpapers, devices and bar preferences",
    settings: [{ key: "confirmDestructive", type: "boolean", label: "Confirm session-ending actions", "default": true }],
    query: function(ctx) { return root.query(ctx) },
    catalog: function(ctx) { return root.catalog(ctx) },
    activate: function(row, ctx) { return root.activate(row) },
    opened: function() { root.reload() }, view: root.view
  })
  readonly property var menus: [
    { id: "session", title: "Session", keywords: "power lock sleep shutdown logout reboot", subtitle: "Lock, sleep or end the session" },
    { id: "capture", title: "Capture", keywords: "screenshot record video annotate", subtitle: "Screenshots and recordings" },
    { id: "theme", title: "Themes", keywords: "appearance colors palette theme", subtitle: "Choose a desktop theme" },
    { id: "backgrounds", title: "Wallpapers", keywords: "background image wallpaper", subtitle: "Choose a wallpaper for the current theme" },
    { id: "audio", title: "Audio", keywords: "sound volume microphone speaker input output", subtitle: "Volume, microphones and audio devices", view: true },
    { id: "net", title: "Network", keywords: "wifi wireless ethernet internet hotspot connection", subtitle: "Connections, Wi-Fi and passwords", view: true },
    { id: "bt", title: "Bluetooth", keywords: "bluetooth pair devices headphones", subtitle: "Pair and manage Bluetooth devices", view: true },
    { id: "display", title: "Displays", keywords: "monitor resolution scale screen brightness", subtitle: "Display modes, scaling and brightness", view: true },
    { id: "tailscale", title: "Tailscale", keywords: "vpn tailnet exit node machines files", subtitle: "Machines, exit nodes and file transfers", view: true },
    { id: "bar", title: "Bar Preferences", keywords: "capsule panel edge position minimal transparency", subtitle: "Position, size and transparency" }
  ]
  readonly property var commands: [
    { id: "action-lock", parent: "session", title: "Lock", subtitle: "Lock the current session", keywords: "screen secure", argv: ["loginctl", "lock-session"] },
    { id: "action-suspend", parent: "session", title: "Suspend", subtitle: "Suspend the computer", keywords: "sleep", argv: ["systemctl", "suspend"] },
    { id: "action-logout", parent: "session", title: "Log out", subtitle: "End the current session", keywords: "exit session uwsm", argv: ["uwsm", "stop"], dangerous: true },
    { id: "action-reboot", parent: "session", title: "Reboot", subtitle: "Restart the computer", keywords: "restart power", argv: ["systemctl", "reboot"], dangerous: true, intentFamily: "restart" },
    { id: "action-poweroff", parent: "session", title: "Shut down", subtitle: "Power off the computer", keywords: "shutdown poweroff power", argv: ["systemctl", "poweroff"], dangerous: true },
    { id: "action-screenshot-region", parent: "capture", title: "Screenshot Region", subtitle: "Select an area, save it, and copy it", keywords: "shot capture grim slurp", argv: ["capture", "shot", "region"] },
    { id: "action-screenshot-window", parent: "capture", title: "Screenshot Window", subtitle: "Save and copy the active window", keywords: "shot capture grim hyprland", argv: ["capture", "shot", "window"] },
    { id: "action-screenshot-screen", parent: "capture", title: "Screenshot Screen", subtitle: "Save and copy the whole screen", keywords: "shot capture grim", argv: ["capture", "shot", "screen"] },
    { id: "action-screenshot-annotate", parent: "capture", title: "Annotate Screenshot", subtitle: "Select an area and edit it in Swappy", keywords: "shot capture swappy edit", argv: ["capture", "annotate", "region"] },
    { id: "action-record-region", parent: "capture", title: "Record Region", subtitle: "Select an area and start recording", keywords: "video capture wf-recorder slurp", argv: ["capture", "record", "region"], intentFamily: "record-start" },
    { id: "action-record-window", parent: "capture", title: "Record Window", subtitle: "Start recording the active window", keywords: "video capture wf-recorder hyprland", argv: ["capture", "record", "window"], intentFamily: "record-start" },
    { id: "action-record-screen", parent: "capture", title: "Record Screen", subtitle: "Start recording the whole screen", keywords: "video capture wf-recorder", argv: ["capture", "record", "screen"], intentFamily: "record-start" },
    { id: "action-record-stop", parent: "capture", title: "Stop Recording", subtitle: "Stop the active wf-recorder capture", keywords: "video capture wf-recorder", argv: ["capture", "record", "stop"], intentFamily: "record-stop" },
    { id: "theme-next", parent: "theme", title: "Next Theme", keywords: "cycle appearance colors", argv: ["theme", "next"], intentFamily: "change" },
    { id: "theme-controls", parent: "theme", title: "Theme Controls", keywords: "appearance swatches preview", page: "theme" },
    { id: "wallpaper-next", parent: "backgrounds", title: "Next Wallpaper", keywords: "cycle background image", argv: ["theme", "bg", "next"], intentFamily: "change" },
    { id: "wallpaper-picker", parent: "backgrounds", title: "Wallpaper Picker", keywords: "background carousel", argv: ["theme", "picker", "backgrounds"], intentFamily: "navigate" },
    { id: "bar-cycle", parent: "bar", title: "Cycle Bar Layout", subtitle: "Pill, full bar or rail", keywords: "capsule panel mode", preference: "cycle" },
    { id: "bar-transparency", parent: "bar", title: "Toggle Bar Transparency", keywords: "translucent opaque capsule", preference: "translucent", intentFamily: "toggle" },
    { id: "bar-top", parent: "bar", title: "Move Bar to Top", preference: "top" },
    { id: "bar-bottom", parent: "bar", title: "Move Bar to Bottom", preference: "bottom" },
    { id: "bar-left", parent: "bar", title: "Move Bar to Left", preference: "left" },
    { id: "bar-right", parent: "bar", title: "Move Bar to Right", preference: "right" }
  ]

  function navRow(menu, order) {
    return { id: menu.id, parent: "root", title: menu.title, subtitle: menu.subtitle, keywords: menu.keywords,
      icon: "󰒓", section: "Desktop", tier: "item", verb: "Open", score: 28, order: order, intentFamily: "navigate",
      action: menu.view ? { type: "system-view", page: menu.id } : { type: "navigate", scope: "system/" + menu.id, title: menu.title } }
  }
  function commandRow(command, settings, order) {
    var effect = command.page ? { type: "system-view", page: command.page }
               : command.preference ? { type: "system-preference", value: command.preference }
               : { type: "exec", argv: command.argv }
    return { id: command.id, parent: command.parent, title: command.title, subtitle: command.subtitle || "",
      keywords: command.keywords || "", icon: "󰒓", section: "Desktop", verb: command.page ? "Open" : "Run",
      tier: "item", order: order, score: 1, remember: true, action: effect,
      intentFamily: command.intentFamily || (command.page ? "navigate" : "action"),
      confirm: command.dangerous && settings.confirmDestructive !== false ? command.title + "? Unsaved work may be lost." : "" }
  }
  function allRows(settings) {
    var rows = [], i
    for (i = 0; i < root.menus.length; i++) rows.push(root.navRow(root.menus[i], i))
    for (i = 0; i < root.commands.length; i++) rows.push(root.commandRow(root.commands[i], settings || {}, rows.length))
    for (var kind = 0; kind < 2; kind++) {
      var data = kind ? root.backgrounds : root.themes
      for (i = 0; i < data.length; i++) {
        var item = data[i]
        if (!item || typeof item.name !== "string" || !item.name || item.name.indexOf("\u0000") >= 0) continue
        rows.push({ id: (kind ? "wallpaper-" : "theme-") + Qt.md5(item.name), parent: kind ? "backgrounds" : "theme",
          title: (kind ? "Wallpaper: " : "Theme: ") + (item.label || item.name), subtitle: item.tagline || "", keywords: item.name,
          icon: "󰒓", section: kind ? "Wallpapers" : "Themes", tier: "item", verb: "Apply", score: 1, order: rows.length,
          accessory: item.current ? "Current" : "", intentFamily: "change", remember: true,
          previewImage: item.image || "", previewLabel: kind ? "WALLPAPER" : "THEME",
          action: { type: "exec", argv: kind ? ["theme", "bg", item.name] : ["theme", item.name] } })
      }
    }
    return rows
  }
  function activeScope(ctx) {
    return ctx.sub || (ctx.scope && ctx.scope.split("/").slice(1).join("/")) || "root"
  }
  function catalog(ctx) {
    if (ctx.scope && ctx.scope.split("/")[0] !== "system") return []
    var active = root.activeScope(ctx)
    return root.allRows(ctx.settings).filter(function(row) { return active === "root" || row.parent === active || row.id === active })
  }
  function query(ctx) {
    if (ctx.scope && ctx.scope.split("/")[0] !== "system") return []
    if (!ctx.scope && !ctx.query)
      return [{ id: "desktop", title: "Desktop Commands", subtitle: "Session, capture, themes and devices", icon: "󰒓", section: "Desktop", tier: "item", verb: "Open", score: 28,
                action: { type: "navigate", scope: "system/root", title: "Desktop" } }]
    var active = root.activeScope(ctx), rows = root.catalog(ctx), out = []
    if ((active === "theme" && !root.themesLoaded) || (active === "backgrounds" && !root.backgroundsLoaded)) {
      root.reload()
      if (ctx.pending) ctx.pending()
    }
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (!ctx.query && active === "root" && row.parent !== "root") continue
      var score = ctx.query ? Match.match(ctx.query, row.title, row.keywords, row.parent, row.subtitle) : 1
      if (score) { row.score = score; out.push(row) }
    }
    if (root.loadError && (active === "theme" || active === "backgrounds"))
      out.push({ id: "theme-error", title: root.loadError, disabled: true, score: 1, action: { type: "noop" } })
    return out
  }

  function activate(row) {
    var action = row.action || { type: "noop" }
    if (action.type === "system-view") {
      root.activePage = action.page
      return { type: "provider-view", provider: "system" }
    }
    if (action.type === "system-preference") {
      if (action.value === "cycle") Desktop.Prefs.cycleBarMode()
      else if (action.value === "translucent") Desktop.Prefs.toggleTranslucent()
      else Desktop.Prefs.setEdge(action.value)
      if (root.host) { root.host.statusMessage = "Bar preference updated"; root.host.requery({ provider: "system" }) }
      return { type: "noop" }
    }
    return action
  }

  // Routes are navigation only. Even a destructive leaf opens its parent menu
  // instead of bypassing the host's confirmation through IPC.
  function routeFor(input) {
    var name = String(input || "").trim().toLowerCase().replace(/^system[\/.]/, "")
    if (name === "apps" || name === "applications") return { kind: "apps", scope: "applications", label: "Applications" }
    var aliases = { themes: "theme", wallpaper: "backgrounds", wallpapers: "backgrounds", background: "backgrounds", network: "net", bluetooth: "bt", displays: "display", desktop: "root", system: "root", power: "session" }
    name = aliases[name] || name
    for (var i = 0; i < root.menus.length; i++) {
      var menu = root.menus[i]
      if (menu.id === name) return { kind: "menu", id: name, scope: "system/" + name, label: menu.title }
    }
    for (i = 0; i < root.commands.length; i++) {
      var command = root.commands[i]
      if (command.id === name || command.id.replace(/^action-/, "") === name || command.title.toLowerCase() === name)
        return { kind: "menu", id: command.parent, scope: "system/" + command.parent, label: command.parent === "session" ? "Session" : "Desktop", query: command.title }
    }
    return { kind: "menu", id: "root", scope: "", label: "" }
  }
  function reload() {
    if (!themeLoader.running) themeLoader.running = true
    if (!backgroundLoader.running) backgroundLoader.running = true
  }
  function acceptRows(text, kind) {
    try {
      var rows = JSON.parse(text)
      if (!Array.isArray(rows)) throw new Error("Invalid rows")
      if (kind === "themes") root.themes = rows
      else root.backgrounds = rows
      root.loadError = ""
    } catch (e) { root.loadError = "Could not load themes or wallpapers" }
  }
  Process {
    id: themeLoader
    command: ["theme", "_rows", "themes"]
    stdout: StdioCollector { onStreamFinished: root.acceptRows(text, "themes") }
    onExited: function(code) {
      root.themesLoaded = true
      if (code !== 0) root.loadError = "Could not load themes"
      if (root.host) root.host.requery({ provider: "system" })
    }
  }
  Process {
    id: backgroundLoader
    command: ["theme", "_rows", "backgrounds"]
    stdout: StdioCollector { onStreamFinished: root.acceptRows(text, "backgrounds") }
    onExited: function(code) {
      root.backgroundsLoaded = true
      if (code !== 0) root.loadError = "Could not load wallpapers"
      if (root.host) root.host.requery({ provider: "system" })
    }
  }

  readonly property Component view: Component {
    Item {
      id: desktopView
      property var host: null
      implicitWidth: 560
      implicitHeight: 540
      function focusInput() { desktopView.forceActiveFocus() }
      function dismiss() { if (menuLoader.item) menuLoader.item.shown = false }
      Keys.onEscapePressed: if (host) host.goBack()
      Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        Text {
          text: "‹ Back to launcher"
          color: Desktop.Theme.fg
          font.family: Desktop.Theme.font
          font.pixelSize: Desktop.Theme.fontSize
          MouseArea { anchors.fill: parent; onClicked: if (desktopView.host) desktopView.host.goBack() }
        }
        Flickable {
          width: parent.width
          height: parent.height - 42
          clip: true
          contentWidth: width
          contentHeight: menuLoader.item ? menuLoader.item.implicitHeight : 0
          Loader {
            id: menuLoader
            width: parent.width
            source: {
              var names = { audio: "AudioMenu", net: "NetMenu", bt: "BtMenu", display: "DisplayMenu", tailscale: "TailscaleMenu", theme: "ThemeMenu" }
              return names[root.activePage] ? Qt.resolvedUrl("../../" + names[root.activePage] + ".qml") : ""
            }
            onLoaded: {
              if ("monitor" in item) item.monitor = desktopView.host && (desktopView.host.targetScreen || desktopView.host.screen) || Quickshell.screens[0] || null
              item.shown = true
            }
          }
          Connections {
            target: menuLoader.item
            ignoreUnknownSignals: true
            function onDismissed() { if (desktopView.host) desktopView.host.cancel() }
            function onNavigate(page) { root.activePage = page }
          }
        }
      }
    }
  }
}
