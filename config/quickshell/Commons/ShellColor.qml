pragma Singleton
// Not "Color": Qt 6.12 exports a QtQuick.Color singleton that shadows it.
import QtQuick
import qs

QtObject {
    readonly property color accent: Theme.accent
    readonly property color urgent: Theme.red
    readonly property var menu: ({
        background: Tokens.surface,
        text: Theme.fg,
        scrim: Theme.alpha(Theme.sunken, 0.76),
        border: Theme.borderActive,
        selectedBackground: Theme.glowFill,
        selectedText: Theme.fg,
        selectedBorder: Theme.borderActive
    })
}
