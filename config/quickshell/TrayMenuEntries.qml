// One level of a tray icon's menu. TrayMenuEntry loads this file again for a
// submenu, so the two stay separate files and the recursion goes through a
// Loader URL rather than a type name, which QML cannot resolve in a cycle.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list

    property var handle: null
    property int depth: 0
    readonly property int count: entries.count
    signal activated()

    spacing: 2

    QsMenuOpener {
        id: opener
        menu: list.handle
    }
    Repeater {
        id: entries
        model: opener.children
        TrayMenuEntry {
            depth: list.depth
            checkable: modelData.buttonType !== QsMenuButtonType.None
            radio: modelData.buttonType === QsMenuButtonType.RadioButton
            onActivated: list.activated()
        }
    }
}
