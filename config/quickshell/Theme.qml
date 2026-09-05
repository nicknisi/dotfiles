pragma Singleton
// Theme.qml - one place for colours and fonts. `pragma Singleton` + Quickshell's
// `Singleton` root means every other file can just say `Theme.bg`; no import or
// qmldir needed, Quickshell registers it from the filename.
import Quickshell
import QtQuick

Singleton {
    // Tokyo Night, carried over from the first draft of the bar.
    readonly property color bg:      "#1a1b26"
    readonly property color bgAlt:   "#232433"
    readonly property color fg:      "#a9b1d6"
    readonly property color muted:   "#444b6a"
    readonly property color cyan:    "#0db9d7"
    readonly property color blue:    "#7aa2f7"
    readonly property color green:   "#9ece6a"
    readonly property color yellow:  "#e0af68"
    readonly property color red:     "#f7768e"

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
    // Colours are Tokyo Night rather than sketchybar's Ayu, so the bar stays
    // internally consistent. Qt reads "#AARRGGBB" when given eight digits.
    readonly property color pillBg:     "#9e232433"
    readonly property color pillBorder: "#1fa9b1d6"
    readonly property color glowFill:   "#247aa2f7"
    readonly property color glowEdge:   "#d97aa2f7"
}
