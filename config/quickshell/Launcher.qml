// Launcher.qml - a resident app launcher with playful motion.
// Desktop entries come from Quickshell, so opening and filtering do not start a
// second program. Built-in session actions join the same searchable list.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "LauncherModel.js" as LauncherModel

Scope {
    id: root

    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    property string pendingAction: ""

    readonly property var actions: [
        { id: "action-lock", kind: "action", name: "Lock", genericName: "Lock the current session", keywords: ["screen", "secure"], glyph: "\uf023", command: ["loginctl", "lock-session"], order: 0, dangerous: false },
        { id: "action-suspend", kind: "action", name: "Suspend", genericName: "Suspend the computer", keywords: ["sleep"], glyph: "\uf186", command: ["systemctl", "suspend"], order: 1, dangerous: false },
        { id: "action-logout", kind: "action", name: "Log out", genericName: "End the current session", keywords: ["exit", "session", "uwsm"], glyph: "\uf2f5", command: ["uwsm", "stop"], order: 2, dangerous: true },
        { id: "action-reboot", kind: "action", name: "Reboot", genericName: "Restart the computer", keywords: ["restart", "power"], glyph: "\uf2f9", command: ["systemctl", "reboot"], order: 3, dangerous: true },
        { id: "action-poweroff", kind: "action", name: "Shut down", genericName: "Power off the computer", keywords: ["shutdown", "poweroff", "power"], glyph: "\uf011", command: ["systemctl", "poweroff"], order: 4, dangerous: true },
        { id: "action-screenshot-region", kind: "action", name: "Screenshot Region", genericName: "Select an area, save it, and copy it", keywords: ["shot", "capture", "grim", "slurp"], glyph: "\uf030", command: ["capture", "shot", "region"], order: 5, dangerous: false },
        { id: "action-screenshot-window", kind: "action", name: "Screenshot Window", genericName: "Save and copy the active window", keywords: ["shot", "capture", "grim", "hyprland"], glyph: "\uf030", command: ["capture", "shot", "window"], order: 6, dangerous: false },
        { id: "action-screenshot-screen", kind: "action", name: "Screenshot Screen", genericName: "Save and copy the whole screen", keywords: ["shot", "capture", "grim"], glyph: "\uf030", command: ["capture", "shot", "screen"], order: 7, dangerous: false },
        { id: "action-screenshot-annotate", kind: "action", name: "Annotate Screenshot", genericName: "Select an area and edit it in Swappy", keywords: ["shot", "capture", "swappy", "edit"], glyph: "\uf044", command: ["capture", "annotate", "region"], order: 8, dangerous: false },
        { id: "action-record-region", kind: "action", name: "Record Region", genericName: "Select an area and start recording", keywords: ["video", "capture", "wf-recorder", "slurp"], glyph: "\uf03d", command: ["capture", "record", "region"], order: 9, dangerous: false },
        { id: "action-record-window", kind: "action", name: "Record Window", genericName: "Start recording the active window", keywords: ["video", "capture", "wf-recorder", "hyprland"], glyph: "\uf03d", command: ["capture", "record", "window"], order: 10, dangerous: false },
        { id: "action-record-screen", kind: "action", name: "Record Screen", genericName: "Start recording the whole screen", keywords: ["video", "capture", "wf-recorder"], glyph: "\uf03d", command: ["capture", "record", "screen"], order: 11, dangerous: false },
        { id: "action-record-stop", kind: "action", name: "Stop Recording", genericName: "Stop the active wf-recorder capture", keywords: ["video", "capture", "wf-recorder"], glyph: "\uf04d", command: ["capture", "record", "stop"], order: 12, dangerous: false }
    ]

    readonly property var resultRows: LauncherModel.buildResults(root.query, DesktopEntries.applications.values, root.actions)

    IpcHandler {
        target: "launcher"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.opened ? root.close() : root.open() }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.pendingAction = ""
    }

    function open() {
        root.query = ""
        root.selectedIndex = 0
        root.pendingAction = ""
        root.opened = true
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    function close() {
        root.opened = false
        root.query = ""
        root.pendingAction = ""
    }

    function moveSelection(delta) {
        const count = root.resultRows.length
        if (!count) return
        root.pendingAction = ""
        root.selectedIndex = (root.selectedIndex + delta + count) % count
        results.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    function activate(row) {
        if (!row) return
        if (row.kind === "action") {
            if (row.dangerous && root.pendingAction !== row.id) {
                root.pendingAction = row.id
                confirmTimer.restart()
                return
            }
            root.close()
            Quickshell.execDetached(row.command)
            return
        }

        const command = ["uwsm-app", "--"]
        if (row.runInTerminal) command.push("ghostty", "-e")
        for (const part of row.command) command.push(part)
        const context = { command }
        if (row.workingDirectory) context.workingDirectory = row.workingDirectory
        root.close()
        Quickshell.execDetached(context)
    }

    onQueryChanged: {
        root.selectedIndex = 0
        root.pendingAction = ""
        Qt.callLater(() => results.positionViewAtBeginning())
    }

    PanelWindow {
        id: panel

        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.sunken, 0.76)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Repeater {
            model: [
                { x: 0.16, y: 0.24, size: 5, delay: 0 },
                { x: 0.82, y: 0.31, size: 3, delay: 420 },
                { x: 0.21, y: 0.73, size: 3, delay: 760 },
                { x: 0.77, y: 0.79, size: 5, delay: 1100 }
            ]

            delegate: Rectangle {
                required property var modelData
                x: panel.width * modelData.x
                y: panel.height * modelData.y
                width: modelData.size * 3
                height: width
                radius: width / 2
                color: Theme.accent
                opacity: 0.18

                SequentialAnimation on opacity {
                    running: root.opened
                    loops: Animation.Infinite
                    PauseAnimation { duration: modelData.delay }
                    NumberAnimation { to: 0.75; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.18; duration: 1200; easing.type: Easing.InOutSine }
                }
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 680)
            height: Math.min(parent.height - 80, 570)
            radius: 24
            color: Theme.alpha(Theme.surface, 0.97)
            border.width: 2
            border.color: root.pendingAction ? Theme.red : Theme.borderActive
            scale: root.opened ? 1 : 0.94
            opacity: root.opened ? 1 : 0

            Behavior on scale { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Rectangle {
                id: searchBox
                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                height: 52
                radius: 16
                color: Theme.raised
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.borderIdle
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    color: Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 17
                }

                TextInput {
                    id: searchInput
                    anchors.left: parent.left
                    anchors.leftMargin: 48
                    anchors.right: escKey.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.surface
                    font.family: Theme.font
                    font.pixelSize: 18
                    clip: true
                    Accessible.name: "Launcher search"
                    onTextChanged: root.query = text

                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close()
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers === Qt.ControlModifier)) {
                            root.moveSelection(1)
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers === Qt.ControlModifier)) {
                            root.moveSelection(-1)
                        } else if (event.key === Qt.Key_Tab) {
                            root.moveSelection(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.resultRows[root.selectedIndex])
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }

                Text {
                    anchors.left: searchInput.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search apps and actions"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 18
                }

                Rectangle {
                    id: escKey
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 22
                    radius: 6
                    color: Theme.sunken
                    border.width: 1
                    border.color: Theme.borderIdle

                    Text {
                        anchors.centerIn: parent
                        text: "esc"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }
            }

            ListView {
                id: results
                anchors.top: searchBox.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.bottomMargin: 8
                clip: true
                spacing: 4
                model: ScriptModel {
                    values: root.resultRows
                    objectProp: "id"
                }
                currentIndex: root.selectedIndex
                highlightMoveDuration: Theme.base
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: result
                    required property var modelData
                    required property int index

                    readonly property var row: modelData
                    readonly property bool selected: index === root.selectedIndex
                    readonly property bool action: row.kind === "action"
                    readonly property bool confirming: root.pendingAction === row.id

                    width: results.width - 14
                    height: 52
                    x: 7
                    rotation: selected ? -0.35 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: result.confirming ? Theme.alpha(Theme.red, 0.18)
                             : result.selected ? Theme.glowFill : "transparent"
                        border.width: result.selected ? 1 : 0
                        border.color: result.confirming ? Theme.red : Theme.alpha(Theme.accent, 0.56)
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: result.selected ? 13 : 18
                        color: result.confirming ? Theme.alpha(Theme.red, 0.22)
                             : result.selected ? Theme.alpha(Theme.accent, 0.18) : Theme.raised
                        rotation: result.selected ? 4 : 0
                        Behavior on radius { NumberAnimation { duration: Theme.base } }
                        Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }

                        IconImage {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            visible: !result.action
                            asynchronous: true
                            source: {
                                if (result.action) return ""
                                return Quickshell.iconPath(result.row.icon || "", true)
                                    || Quickshell.iconPath("org.quickshell")
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: result.action
                            text: result.row.glyph || Icons.fallback
                            color: result.confirming ? Theme.red : Theme.accent
                            font.family: Theme.icons
                            font.pixelSize: 17
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.right: hint.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: result.row.name || ""
                            color: result.confirming ? Theme.red : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.bold: result.selected
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: result.row.genericName || result.row.comment || ""
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: result.selected
                        text: result.confirming ? "enter again" : "open  ↵"
                        color: result.confirming ? Theme.red : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedIndex = result.index
                            if (!result.confirming) root.pendingAction = ""
                        }
                        onClicked: root.activate(result.row)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.resultRows.length === 0
                    text: "No matches"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 14
                }
            }

            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 38

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.borderIdle
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.pendingAction ? "Press Enter again to confirm." : root.resultRows.length + (root.resultRows.length === 1 ? " result" : " results")
                    color: root.pendingAction ? Theme.red : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.pendingAction
                    text: "↑↓ select   ↵ open   esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
