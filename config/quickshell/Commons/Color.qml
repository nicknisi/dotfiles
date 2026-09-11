pragma Singleton
import QtQuick
import qs

QtObject {
    readonly property color accent: Theme.accent
    readonly property color urgent: Theme.red
    readonly property var menu: ({
        background: Theme.surface,
        text: Theme.fg,
        scrim: Theme.alpha(Theme.sunken, 0.76),
        border: Theme.borderActive,
        selectedBackground: Theme.glowFill,
        selectedText: Theme.fg,
        selectedBorder: Theme.borderActive
    })
}
