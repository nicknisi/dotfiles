pragma Singleton
// Theme.qml - one place for colours and fonts. `pragma Singleton` + Quickshell's
// `Singleton` root means every other file can just say `Theme.bg`; no import or
// qmldir needed, Quickshell registers it from the filename.
//
// Colours come from the active theme: bin/theme writes the resolved palette to
// ~/.local/state/theme/current/colors.json on every switch. The file is watched
// (and `qs ipc call theme reload` is a belt to that suspender), so the bar
// retints without a restart. The literals below are Tokyo Night, the look until
// theme has run once on a machine.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var palette: ({})
    function c(key, fallback) { return palette[key] || fallback }
    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a) }

    readonly property color bg:      c("background",         "#1a1b26")
    readonly property color bgAlt:   c("lighter_background", "#232433")
    readonly property color fg:      c("foreground",         "#a9b1d6")
    readonly property color muted:   c("muted",              "#444b6a")
    readonly property color accent:  c("accent",             "#7aa2f7")
    readonly property color cyan:    c("cyan",               "#0db9d7")
    readonly property color blue:    c("blue",               "#7aa2f7")
    readonly property color green:   c("green",              "#9ece6a")
    readonly property color yellow:  c("yellow",             "#e0af68")
    readonly property color red:     c("red",                "#f7768e")
    readonly property bool  dark:    c("mode", "dark") !== "light"

    // The old config asked for "JetBrainsMono Nerd Font", which is not installed,
    // so Qt was silently falling back. These two are.
    readonly property string font:  "Monaspace Argon"
    readonly property string icons: "Symbols Nerd Font"

    readonly property int fontSize:  13
    readonly property int iconSize:  14
    readonly property int barHeight: 30

    // Workspace pills. The structure is lifted from sketchybar's colors.sh: a
    // translucent accent fill under a bright accent border for the focused one,
    // a flat dark chip under a 12%-opacity hairline for merely occupied ones.
    readonly property color pillBg:     alpha(bgAlt,  0.62)
    readonly property color pillBorder: alpha(fg,     0.12)
    readonly property color glowFill:   alpha(accent, 0.14)
    readonly property color glowEdge:   alpha(accent, 0.85)

    function reload() { file.reload() }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/theme/current/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.palette = JSON.parse(text()) } catch (e) { /* half-written; the next change wins */ }
        }
    }
}
