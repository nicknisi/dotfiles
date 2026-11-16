pragma Singleton
// Theme.qml - one place for colours and fonts. `pragma Singleton` + Quickshell's
// `Singleton` root means every other file can just say `Theme.bg`; no import or
// qmldir needed, Quickshell registers it from the filename.
//
// Colours come from the active theme: bin/theme writes the resolved palette to
// ~/.local/state/theme/current/colors.json on every switch. The file is watched
// (and `qs ipc call theme reload` is a belt to that suspender), so the bar
// retints without a restart. The literals below are Tokyo Night, the look until
// theme has run once on a machine. $THEME_COLORS overrides the path (sandbox).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQml
import QtQuick
import "BarGeometry.js" as BarGeometry

Singleton {
    id: root

    property var palette: ({})
    function c(key, fallback) { return palette[key] || fallback }
    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a) }
    function luminance(color) {
        function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
    }
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }

    readonly property color bg:      c("background",         "#1a1b26")
    readonly property color bgAlt:   c("lighter_background", "#232433")
    readonly property color fg:      c("foreground",         "#a9b1d6")
    readonly property color muted:   c("muted",              "#444b6a")
    readonly property color accent:  c("accent",             "#7aa2f7")
    readonly property color accentText: root.contrast(root.accent, root.fg) >= root.contrast(root.accent, root.bg) ? root.fg : root.bg
    readonly property color cyan:    c("cyan",               "#0db9d7")
    readonly property color blue:    c("blue",               "#7aa2f7")
    readonly property color green:   c("green",              "#9ece6a")
    readonly property color yellow:  c("yellow",             "#e0af68")
    readonly property color red:     c("red",                "#f7768e")
    readonly property bool  dark:    c("mode", "dark") !== "light"
    readonly property string name:   c("name", "")

    // ---- surfaces ----------------------------------------------------------
    // Three steps, darkest to lightest. A menu floats above the bar, which
    // floats above the desktop, and none of them has to guess at a hex value.
    readonly property color sunken:  c("darker_background",  "#12131f")
    readonly property color surface: bg
    readonly property color raised:  bgAlt
    // Secondary labels stay readable even when the palette's muted color is
    // intended for borders rather than text.
    readonly property color secondary: Qt.tint(surface, alpha(fg, 0.68))

    readonly property int controlRadius: 12
    readonly property int panelRadius: 28
    // Neutral shadows work with every palette. Match Hyprland's 0x30 alpha.
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 48 / 255)
    readonly property int shadowBlur: 16
    readonly property int shadowPadding: shadowBlur

    // Single-color borders for shell controls. Window borders live in hyprland.lua.tpl.
    readonly property color borderActive: accent
    readonly property color borderIdle:   alpha(muted, 0.67)

    // ---- motion ------------------------------------------------------------
    // Three speeds, so every animation in the shell agrees with the others.
    // quick is for a hover tint, base for anything that moves, unfold for a menu
    // opening, which is slow enough to read as a physical thing.
    readonly property int quick:  90
    readonly property int base:   160
    readonly property int unfold: 220

    // The old config asked for "JetBrainsMono Nerd Font", which is not installed,
    // so Qt was silently falling back. These two are.
    readonly property string font:  "Monaspace Argon"
    readonly property string uiFont: "Adwaita Sans"
    readonly property string headingFont: "Adwaita Sans"
    readonly property string icons: "Symbols Nerd Font"

    readonly property int fontSize:  13
    readonly property int iconSize:  14
    readonly property int barHeight: 40
    // 8 for the floating pill; the full strip and the rail are flush (M4).
    readonly property int barInset: BarGeometry.inset(Prefs.barMode)
    // The exclusive zone Reserve holds along the bar's edge: 56 for the pill,
    // 40 for the full strip and the rail, 46 for the island (40 in its notch form). The island is 38
    // high, 8 under the top edge, and Hyprland adds gaps_out (8) below the zone
    // itself, so 46 puts window edges 8 under the island (Main board: y 54).
    // The notch form (M9, Prefs.islandForm) is flush with the top edge and
    // 40 high, so it reserves 40: window edges 8 under it once more.
    readonly property int islandExtent: Prefs.islandForm === "notch" ? 40 : 46
    readonly property int barExtent: Prefs.barMode === "island" ? islandExtent : barHeight + 2 * barInset

    // A light accent wash for selected controls, independent of theme mode.
    readonly property color glowFill: alpha(accent, 0.14)

    // Shell surfaces (HUD, launcher, notification center) go see-through with
    // the capsule; Hyprland blurs behind them (shell-blur rule in hyprland.lua).
    readonly property real surfaceOpacity: Prefs.translucent ? 0.82 : 1

    // ---- window manager geometry -------------------------------------------
    // Keep window-manager geometry for window-like overlays. The capsule and
    // HUD have their own rounded silhouette, regardless of window rounding.
    //
    // Read through hyprctl rather than Quickshell.Hyprland because that module
    // exposes workspaces and monitors, not config options.
    property int gap: 8
    property int borderWidth: 2
    property int radius: 0

    function readGeometry() { geometry.running = true }

    Process {
        id: geometry
        running: true
        command: ["sh", "-c",
            "hyprctl -j getoption general:gaps_out; " +
            "hyprctl -j getoption general:border_size; " +
            "hyprctl -j getoption decoration:rounding"
        ]

        stdout: SplitParser {
            onRead: line => {
                let o;
                try { o = JSON.parse(line) } catch (e) { return }
                switch (o.option) {
                // gaps_out comes back as a css-style "8 8 8 8" string rather
                // than an int, since it is four numbers wearing one name.
                case "general:gaps_out":     root.gap = parseInt(String(o.css).split(/\s+/)[0]) || 8; break;
                case "general:border_size":  root.borderWidth = o.int ?? 2; break;
                case "decoration:rounding":  root.radius = o.int ?? 0; break;
                }
            }
        }
    }

    // Hyprland announces its own reloads, which is when those three can change.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.readGeometry();
        }
    }

    function reload() { file.reload() }

    // $THEME_COLORS, when set, names another colors.json: the sandbox renders any
    // pack with `bin/theme-color --json` and points the shell at that file.
    readonly property string colorsPath: Quickshell.env("THEME_COLORS")
        || Quickshell.env("HOME") + "/.local/state/theme/current/colors.json"

    FileView {
        id: file
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.palette = JSON.parse(text()) } catch (e) { /* half-written; the next change wins */ }
        }
    }
}
