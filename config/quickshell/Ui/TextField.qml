import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.TextField {
    id: root
    property color foreground: Color.menu.text
    property color accent: Color.accent
    color: foreground
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
    padding: Style.space(10)
    selectByMouse: true
    selectionColor: Style.selectionFillFor(foreground, accent)
    selectedTextColor: foreground
    placeholderTextColor: Util.alpha(foreground, 0.55)
    background: BorderSurface {
        radius: Style.cornerRadius
        color: Style.controlFill(root.activeFocus, root.hovered, root.foreground, root.accent)
        borderSpec: Border.controlSpec(root.activeFocus ? "focus" : "normal", root.foreground, root.accent)
    }
}
