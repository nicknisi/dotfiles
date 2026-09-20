// One row of a tray icon's menu: a separator, a plain item, a check or radio
// item, or a submenu that unfolds beneath it.
//
// No Quickshell import here on purpose: the QsMenuButtonType enum is read by
// TrayMenuEntries, which hands over two booleans, so this file also loads in
// qmltestrunner, where Quickshell's QML plugin is not available.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: row

    required property var modelData
    property int depth: 0
    property bool expanded: false
    property bool checkable: false
    property bool radio: false
    signal activated()

    readonly property var entry: modelData
    readonly property bool checked: entry.checkState === Qt.Checked

    Layout.fillWidth: true
    spacing: 2

    MenuRule {
        visible: row.entry.isSeparator
    }

    BarModule {
        id: button
        objectName: "trayEntryButton"
        visible: !row.entry.isSeparator
        enabled: row.entry.enabled
        Layout.fillWidth: true
        implicitHeight: 34
        padding: 10
        leftPadding: 10 + row.depth * 14
        cornerRadius: Theme.controlRadius
        text: row.entry.text
        highlighted: row.expanded
        onClicked: {
            if (row.entry.hasChildren) {
                row.expanded = !row.expanded;
                // DBusMenu wants to know when a submenu shows, so the app can
                // fill it in (AboutToShow); the signals are the way to say so.
                if (row.expanded) row.entry.opened(); else row.entry.closed();
                return;
            }
            row.entry.triggered();
            row.activated();
        }

        Text {
            objectName: "trayEntryCheck"
            visible: row.checkable
            text: row.radio ? (row.checked ? "\u{f043e}" : "\u{f043d}") : (row.checked ? "\u{f0132}" : "\u{f0131}")
            font.family: Theme.icons
            font.pixelSize: 14
            color: row.checked ? Theme.accent : Theme.secondary
            Layout.alignment: Qt.AlignVCenter
        }
        Image {
            visible: row.entry.icon !== "" && !row.checkable
            source: row.entry.icon
            sourceSize.width: 16
            sourceSize.height: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            Layout.fillWidth: true
            text: row.entry.text
            textFormat: Text.PlainText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fg
            elide: Text.ElideRight
        }
        Text {
            objectName: "trayEntryChevron"
            visible: row.entry.hasChildren
            text: row.expanded ? "\u{f0140}" : "\u{f0142}"
            font.family: Theme.icons
            font.pixelSize: 14
            color: Theme.secondary
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Loader {
        Layout.fillWidth: true
        active: row.expanded && row.entry.hasChildren
        source: "TrayMenuEntries.qml"
        onLoaded: {
            item.handle = row.entry;
            item.depth = row.depth + 1;
            item.activated.connect(row.activated);
        }
    }
}
