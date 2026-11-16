import QtQuick
import qs
import qs.Kit

// PowerLayer.qml - the power menu, as the island itself (control-lock 5,
// Main board `power`, 600 x 156, over the scrim).
//
//   ←16→ [ 🔒 ] [ ☾ ] [ ⇥ ] [ ↻ ] [ ⏻ ] ←16→     5 columns, 8 apart, 98 high
//          Lock  Suspend Log out Reboot Shut down
//           L      S      E      R      P
//        Arrow keys move · Enter confirms · Esc cancels      11 `inkDim`
//
// Padding 16 16 12, a column 10 apart (16 + 98 + 10 + 14 + 12 = 150 of the
// 156). Items: radius 14, a column centred 8 apart: icon 22, label 13, key
// badge (Monaspace 10, padding 1 5, radius 4, `fillHigh`, `inkDim`). The
// selected one is `accentTint` with a 1 px `accent` ring and its icon in
// `accent`; the others `raised`, `hairline`, `fg`. The first item (Lock in
// the island) is selected when it opens.
//
// Keys (today's behaviour wins over the board's go-on-press): a letter
// selects its item, the arrows move (wrapping), Enter or Space runs the
// selected one, Esc cancels. A click selects and runs. Nothing here runs a
// command: run(id) asks the host (IslandView), which never does under a
// fixture or in the sandbox.
//
// objectNames: powerItem-lock|suspend|logout|reboot|shutdown.
//
// QtQuick only: Lock/LockSurface.qml hosts it too, and qmltestrunner loads it.
Layer {
    id: power

    // Every item, in order (commands from launcher/providers/System.qml).
    readonly property var allItems: [
        { id: "lock", label: "Lock", key: "L", icon: "lock" },
        { id: "suspend", label: "Suspend", key: "S", icon: "moon" },
        { id: "logout", label: "Log out", key: "E", icon: "logout" },
        { id: "reboot", label: "Reboot", key: "R", icon: "restart" },
        { id: "shutdown", label: "Shut down", key: "P", icon: "power" }
    ]
    // The items shown: all five in the island; the lock screen keeps Suspend,
    // Reboot and Shut down (control-lock 5: Lock means nothing there, and Log
    // out would end the session without a password). Set once, never bound to
    // a freshly built array (the Repeater would rebuild on every change).
    property var items: allItems
    // An item's width: the island's five fill its 600, (600 - 32 - 4 * 8) / 5.
    // A host with fewer items sets its own, so the menu lands on whole device
    // pixels (Lock/LockSurface.qml: 108, a 372 wide menu).
    property real itemWidth: 107.2
    property int selected: 0
    readonly property string selectedId: items[selected]?.id ?? ""
    readonly property alias grid: grid
    readonly property alias repeater: itemRepeater
    readonly property alias hint: hint

    signal run(string id)
    signal cancel

    width: 32 + items.length * itemWidth + Math.max(0, items.length - 1) * 8
    height: 156
    focus: current

    Accessible.role: Accessible.Dialog
    Accessible.name: "Power menu"

    onCurrentChanged: if (current) selected = 0

    function select(index: int) {
        const n = items.length;
        selected = ((index % n) + n) % n;
    }
    // A letter key: its item, or -1.
    function indexForKey(text: string): int {
        const t = String(text).toUpperCase();
        return items.findIndex(i => i.key === t);
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) return;
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_Up: case Qt.Key_Backtab:
            select(selected - 1);
            break;
        case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab:
            select(selected + 1);
            break;
        case Qt.Key_Home:
            select(0);
            break;
        case Qt.Key_End:
            select(items.length - 1);
            break;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
            power.run(power.selectedId);
            break;
        case Qt.Key_Escape:
            power.cancel();
            break;
        default: {
            const i = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier) ? -1 : indexForKey(event.text);
            if (i < 0) return;
            select(i);
        }
        }
        event.accepted = true;
    }

    Row {
        id: grid
        x: 16
        y: 16
        width: parent.width - 32
        height: 98
        spacing: 8
        Repeater {
            id: itemRepeater
            model: power.items
            Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool isSelected: power.selected === index
                objectName: "powerItem-" + modelData.id
                width: power.itemWidth
                height: 98
                radius: 14
                color: isSelected ? Tokens.accentTint : Tokens.raised
                border.width: 1
                border.color: isSelected ? Tokens.accent : Tokens.hairline
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label + ", " + modelData.key
                Accessible.selected: isSelected
                Accessible.onPressAction: power.run(modelData.id)

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: item.modelData.icon
                        size: 22
                        color: item.isSelected ? Tokens.accent : Tokens.fg
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: item.modelData.label
                        color: Tokens.fg
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                    }
                    Keycap {
                        anchors.horizontalCenter: parent.horizontalCenter
                        small: true
                        fontSize: 10
                        ink: Tokens.inkDim
                        text: item.modelData.key
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: power.select(item.index)
                    onClicked: {
                        power.select(item.index);
                        power.run(item.modelData.id);
                    }
                }
            }
        }
    }

    Text {
        id: hint
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.y + grid.height + 10
        text: "Arrow keys move · Enter confirms · Esc cancels"
        color: Tokens.inkDim
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: 11
    }
}
