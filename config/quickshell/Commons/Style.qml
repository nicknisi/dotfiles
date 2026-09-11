pragma Singleton
import QtQuick
import qs

QtObject {
    readonly property int gapsOut: Theme.gap
    readonly property int cornerRadius: Theme.controlRadius
    readonly property var font: ({
        menuFamily: Theme.font, iconFamily: Theme.icons,
        caption: 10, bodySmall: 11, body: Theme.fontSize,
        title: 14, heading: 18, display: 28, displayLarge: 36,
        icon: Theme.iconSize, iconLarge: 19
    })
    function space(value) { return Math.round(value) }
    function selectionFillFor(foreground, accent) { return Util.alpha(accent, 0.35) }
    function controlFill(focused, hovered, foreground, accent) {
        return Util.alpha(focused ? accent : foreground, focused ? 0.14 : hovered ? 0.1 : 0.05)
    }
}
