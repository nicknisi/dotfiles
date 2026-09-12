// DisplayMenu.qml - Hyprland mode and scale for the monitor this bar lives on.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    property var monitor: null
    property var display: ({ current: {}, modes: [], scales: [] })
    property string error: ""
    readonly property bool busy: query.running || action.running
    readonly property string output: String(menu.monitor?.name ?? "")
    readonly property string currentMode: String(menu.display.current?.mode ?? "current")

    menuWidth: 320
    title: "Display"
    subtitle: menu.display.output
        ? `${menu.display.output} · ${menu.display.current.width}×${menu.display.current.height} · ${menu.display.current.scale}×`
        : "resolution and scale"

    onShownChanged: {
        if (menu.shown) menu.refresh();
        else menu.error = "";
    }

    function refresh(): void {
        if (!menu.shown || query.running) return;
        query.command = ["display-mode", "json", menu.output];
        query.running = true;
    }

    function apply(mode: string, scale: real): void {
        if (menu.busy || !(menu.display.output || menu.output)) return;
        menu.error = "";
        action.command = ["display-mode", "set", menu.display.output || menu.output, mode, String(scale)];
        action.running = true;
    }

    component Label: Text {
        textFormat: Text.PlainText
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
    }

    component ChoiceRow: MenuAction {
        id: row

        property string label: ""
        property string caption: ""
        property bool current: false
        property bool busy: false
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 30
        enabled: !row.current && !row.busy
        cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        Accessible.name: row.current ? `Current display mode ${row.label}` : `Apply display mode ${row.label}`
        onClicked: if (row.enabled) row.picked()

        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: row.containsMouse && row.enabled ? Theme.raised : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: parent.height - 10
            color: Theme.borderActive
            visible: row.current
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: row.label
                font.bold: row.current
                color: row.current ? Theme.fg : Theme.secondary
            }
            Label {
                text: row.current ? "current" : row.caption
                color: row.current ? Theme.accent : Theme.muted
                font.pixelSize: Theme.fontSize - 3
            }
        }
    }

    Process {
        id: query
        stdout: StdioCollector { id: queryOut }
        stderr: StdioCollector { id: queryErr }
        onExited: code => {
            if (!menu.shown) return;
            if (code !== 0) {
                menu.error = queryErr.text.trim() || "Could not read display modes";
                return;
            }
            try {
                menu.display = JSON.parse(queryOut.text.trim());
            } catch (e) {
                menu.error = "Could not read display modes";
            }
        }
    }

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            if (code !== 0) menu.error = actionErr.text.trim() || "Display change failed";
            refreshLater.restart();
        }
    }

    Timer {
        id: refreshLater
        interval: 500
        onTriggered: menu.refresh()
    }

    MenuHint {
        visible: menu.error !== ""
        text: menu.error
        color: Theme.red
    }

    MenuHeading { text: "mode" }

    Repeater {
        model: menu.display.modes ?? []

        ChoiceRow {
            required property var modelData
            label: modelData.label
            caption: "apply"
            current: modelData.current
            busy: menu.busy
            onPicked: menu.apply(modelData.mode, menu.display.current.scale ?? 1)
        }
    }

    MenuHeading { text: "scale" }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 6
        rowSpacing: 6

        Repeater {
            model: menu.display.scales ?? []

            BarModule {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 68
                text: `Scale ${modelData.label}`
                highlighted: modelData.current
                enabled: !modelData.current && !menu.busy
                onClicked: menu.apply(menu.currentMode, modelData.value)

                Label {
                    Layout.alignment: Qt.AlignCenter
                    text: modelData.label
                    font.bold: modelData.current
                    color: modelData.current ? Theme.accent : Theme.secondary
                }
            }
        }
    }

    MenuHint {
        visible: menu.busy
        text: "applying..."
    }
}
