// The menu of one tray icon, drawn as a HUD page so it matches the capsule's
// other menus instead of whatever toolkit the application would pop up.
//
// StatusNotifierItem menus arrive over D-Bus as a tree (DBusMenu); QsMenuOpener
// turns one level of it into QsMenuEntry objects. Submenus unfold in place,
// indented, rather than opening a second popup: the HUD is a single popup
// with a single focus grab, and a nested Wayland popup would fight it.
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    property var item: null

    menuWidth: 300

    TrayMenuEntries {
        id: entries
        Layout.fillWidth: true
        handle: menu.item ? menu.item.menu : null
        onActivated: menu.dismissed()
    }
    MenuHint {
        visible: entries.count === 0
        text: menu.item && menu.item.hasMenu ? "Loading the menu…" : "This app has no menu"
    }
}
