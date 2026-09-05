// Theme.qml - one place for colours and fonts. `pragma Singleton` + Quickshell's
// `Singleton` root means every other file can just say `Theme.bg`; no import or
// qmldir needed, Quickshell registers it from the filename.
pragma Singleton
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
}
