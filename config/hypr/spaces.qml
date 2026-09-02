// AeroSpace-style workspace pills for the omarchy-shell bar.
// Ported from the macOS SketchyBar renderer (config/sketchybar/plugins/workspaces.sh):
// a pill per space (1-9 + letter workspaces), Nerd Font app glyphs of the
// windows living on it, empty spaces hidden, focused space glowing.
//
// Wired up in ~/.config/omarchy/shell.json:
//   { "id": "spaces", "source": "~/.config/hypr/spaces.qml" }
// replacing the stock "omarchy.workspaces" entry.
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "spaces"

  // Spaces in bar order, matching the SUPER bindings in hypr/bindings.lua.
  readonly property var spaces: [
    { key: "1" }, { key: "2" }, { key: "3" }, { key: "4" }, { key: "5" },
    { key: "6" }, { key: "7" }, { key: "8" }, { key: "9" },
    { key: "W", label: "Web" },
    { key: "A", label: "AI" },
    { key: "S", label: "Productivity" },
    { key: "D", label: "Development" },
    { key: "Z", label: "Screen share" },
    { key: "X", label: "Tasks" },
    { key: "C", label: "Chat" }
  ]

  // Window class -> Nerd Font glyph (mirrors sketchybar plugins/icons.sh).
  function appGlyph(cls) {
    var c = String(cls || "").toLowerCase()
    if (c === "")
      return ""
    if (c.indexOf("ghostty") >= 0 || c.indexOf("wezterm") >= 0 || c.indexOf("kitty") >= 0 || c.indexOf("alacritty") >= 0 || c.indexOf("foot") >= 0)
      return "\uf489" // terminal
    if (c.indexOf("helium") >= 0 || c.indexOf("chrome") >= 0 || c.indexOf("safari") >= 0 || c.indexOf("brave") >= 0)
      return "\uf268" // chrome-ish browser
    if (c.indexOf("firefox") >= 0 || c.indexOf("zen") >= 0)
      return "\uf269" // firefox
    if (c.indexOf("slack") >= 0)
      return "\uf198" // slack
    if (c.indexOf("discord") >= 0 || c.indexOf("signal") >= 0 || c.indexOf("telegram") >= 0 || c.indexOf("whatsapp") >= 0 || c.indexOf("messages") >= 0)
      return "\uf086" // chat
    if (c.indexOf("code") >= 0 || c.indexOf("nvim") >= 0)
      return "\uf121" // code
    if (c.indexOf("obsidian") >= 0 || c.indexOf("notion") >= 0)
      return "\uf02d" // notes
    if (c.indexOf("spotify") >= 0 || c.indexOf("music") >= 0 || c.indexOf("cliamp") >= 0)
      return "\uf001" // music
    if (c.indexOf("zoom") >= 0 || c.indexOf("facetime") >= 0)
      return "\uf03d" // video
    return "\uf2d0" // generic window
  }

  // HyprlandToplevel exposes the hyprctl client fields via lastIpcObject;
  // fall back to a direct class property in case the API shape differs.
  function toplevelGlyph(t) {
    try {
      var cls = (t && t.lastIpcObject && t.lastIpcObject.class) || (t && t.class) || ""
      return appGlyph(cls)
    } catch (e) {
      return ""
    }
  }

  function spaceByName(key) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].name === key)
        return values[i]
    }
    return null
  }

  function focusSpace(key) {
    if (!root.bar)
      return
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "name:' + key + '" })'))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(3)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.spaces.length
    columnSpacing: root.vertical ? 0 : Style.space(3)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.spaces

      Item {
        id: pill
        required property var modelData

        readonly property var ws: root.spaceByName(modelData.key)
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.name === modelData.key
        readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0
        // SketchyBar parity: hide empty, unfocused spaces entirely.
        readonly property bool shown: focused || occupied
        // Unique app glyphs, capped so wide workspaces stay compact.
        readonly property string glyphs: {
          var out = ""
          var seen = {}
          var list = ws !== null ? ws.toplevels.values : []
          for (var i = 0; i < list.length && out.length < 4; i++) {
            var g = root.toplevelGlyph(list[i])
            if (g !== "" && seen[g] === undefined) {
              seen[g] = true
              out += g
            }
          }
          return out
        }

        visible: shown
        implicitWidth: row.implicitWidth + Style.space(12)
        implicitHeight: root.barSize

        RowLayout {
          id: row
          anchors.centerIn: parent
          spacing: Style.space(1.5)

          Text {
            text: pill.modelData.key
            color: pill.focused ? root.bar ? root.bar.urgent : Color.urgent : root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.bold: pill.focused
            font.pixelSize: Style.bar.iconFont
            renderType: Text.NativeRendering
          }

          Text {
            visible: pill.glyphs !== ""
            text: pill.glyphs
            color: pill.focused ? root.bar ? root.bar.urgent : Color.urgent : root.bar ? root.bar.barForeground : Color.foreground
            font.family: "Symbols Nerd Font Mono"
            font.pixelSize: Style.bar.iconFont
            renderType: Text.NativeRendering
          }
        }

        // Focus glow: faint urgent wash on the focused pill, whisper of a
        // fill on occupied ones (SketchyBar's GLOW_FILL / PILL_BG).
        Rectangle {
          z: -1
          anchors.fill: parent
          anchors.topMargin: Style.space(1)
          anchors.bottomMargin: Style.space(1)
          radius: 6
          color: pill.focused ? Util.alpha(root.bar ? root.bar.urgent : Color.urgent, 0.18) : pill.occupied ? Util.alpha(root.bar ? root.bar.barForeground : Color.foreground, 0.07) : "transparent"
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusSpace(pill.modelData.key)
          onEntered: if (root.bar && pill.modelData.label)
            root.bar.showTooltip(pill, pill.modelData.label)
          onExited: if (root.bar)
            root.bar.hideTooltip(pill)
        }
      }
    }
  }
}
