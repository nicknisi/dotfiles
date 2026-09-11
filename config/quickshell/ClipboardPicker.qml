// Searchable text, image, and video clipboard history backed by cliphist.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ClipboardModel.js" as ClipboardModel

Scope {
    id: root

    property bool opened: false
    property var targetScreen: null
    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property var pendingEntries: []

    readonly property string mediaCache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard-media"
    readonly property string mediaIndex: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/cliphist/media.tsv"
    readonly property var resultRows: ClipboardModel.filter(entries, query)

    IpcHandler {
        target: "clipboard"
        function open(screenName: string): void { root.open(screenName) }
        function close(): void { root.close() }
        function toggle(screenName: string): void { root.opened ? root.close() : root.open(screenName) }
        function clear(): void { root.clearHistory() }
    }

    // Separate MIME watchers ensure browsers' image data wins over text fallbacks.
    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && exec wl-paste --type text --watch cliphist store"]
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && exec wl-paste --type image --watch cliphist store"]
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v clipboard-store-video >/dev/null 2>&1 && exec wl-paste --type video --watch clipboard-store-video"]
    }

    Process {
        id: loader
        command: ["clipboard-list"]
        stdout: SplitParser {
            onRead: line => {
                const tab = line.indexOf("\t");
                if (tab <= 0) return;
                const id = line.slice(0, tab);
                if (!/^\d+$/.test(id)) return;
                const preview = line.slice(tab + 1);
                root.pendingEntries.push(ClipboardModel.entry(id, preview));
            }
        }
        onExited: {
            root.entries = root.pendingEntries;
            root.selectedIndex = 0;
        }
    }

    Process { id: paste }

    Process {
        id: wipe
        command: [
            "sh", "-c", "cliphist wipe && rm -rf -- \"$1\" && rm -f -- \"$2\" \"$2.lock\"",
            "clipboard-history", root.mediaCache, root.mediaIndex
        ]
        onExited: (code, status) => {
            if (code === 0) {
                root.entries = [];
                root.selectedIndex = 0;
            }
        }
    }

    function screenFor(name): var {
        for (const screen of Quickshell.screens)
            if (screen.name === name) return screen;
        return Quickshell.screens.length ? Quickshell.screens[0] : null;
    }

    function open(screenName): void {
        targetScreen = screenFor(screenName);
        searchInput.text = "";
        query = "";
        selectedIndex = 0;
        pendingEntries = [];
        opened = targetScreen !== null;
        if (!loader.running) loader.running = true;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function close(): void {
        opened = false;
        searchInput.text = "";
        query = "";
    }

    function moveSelection(delta): void {
        if (!resultRows.length) return;
        selectedIndex = (selectedIndex + delta + resultRows.length) % resultRows.length;
        results.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate(row): void {
        if (!row || paste.running) return;
        const path = row.kind === "text" ? "" : `${mediaCache}/${row.id}.${row.extension}`;
        close();
        paste.command = ["clipboard-paste", row.id, row.mime, path];
        paste.running = true;
    }

    function clearHistory(): void {
        if (!wipe.running) wipe.running = true;
    }

    onQueryChanged: {
        selectedIndex = 0;
        Qt.callLater(() => results.positionViewAtBeginning());
    }

    PanelWindow {
        id: panel

        visible: root.opened
        screen: root.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "clipboard-history"
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

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 680)
            height: Math.min(parent.height - 80, 540)
            radius: Theme.panelRadius
            color: Theme.surface
            border.width: 2
            border.color: Theme.borderActive
            scale: root.opened ? 1 : 0.94
            opacity: root.opened ? 1 : 0
            SurfaceShadow { surface: card }

            Behavior on scale { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: Theme.base } }
            MouseArea { anchors.fill: parent; onClicked: {} }

            Text {
                id: heading
                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.leftMargin: 22
                text: "Clipboard history"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 5
                font.bold: true
            }

            Text {
                anchors.baseline: heading.baseline
                anchors.right: parent.right
                anchors.rightMargin: 22
                text: `${root.entries.length} saved`
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            Rectangle {
                id: searchBox
                anchors.top: heading.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                height: 50
                radius: Theme.controlRadius
                color: Theme.raised
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.borderIdle

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.accent
                    font.family: Theme.icons
                    font.pixelSize: 16
                }

                TextInput {
                    id: searchInput
                    anchors.left: parent.left
                    anchors.leftMargin: 46
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.surface
                    font.family: Theme.font
                    font.pixelSize: 17
                    clip: true
                    Accessible.name: "Search clipboard history"
                    onTextChanged: root.query = text

                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers === Qt.ControlModifier)) {
                            root.moveSelection(1);
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers === Qt.ControlModifier)) {
                            root.moveSelection(-1);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.resultRows[root.selectedIndex]);
                        } else if (event.key === Qt.Key_Delete && event.modifiers === Qt.ControlModifier) {
                            root.clearHistory();
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.left: searchInput.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search clipboard history"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 17
                }
            }

            ListView {
                id: results
                anchors.top: searchBox.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.bottomMargin: 8
                clip: true
                spacing: 4
                model: root.resultRows
                currentIndex: root.selectedIndex
                highlightMoveDuration: Theme.base
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.selectedIndex
                    readonly property bool media: modelData.kind !== "text"
                    readonly property string thumbnailPath: `${root.mediaCache}/${modelData.id}.${modelData.extension}`
                    property bool thumbnailReady: false

                    width: results.width
                    height: modelData.kind === "image" ? 96 : media ? 64 : 48
                    radius: 13
                    color: selected ? Theme.glowFill : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.56)

                    Process {
                        command: [
                            "sh", "-c",
                            "mkdir -p -- \"$1\" && cliphist decode \"$2\" >\"$3\"",
                            "clipboard-thumbnail", root.mediaCache, row.modelData.id, row.thumbnailPath
                        ]
                        Component.onCompleted: if (row.modelData.kind === "image") running = true
                        onExited: (code, status) => row.thumbnailReady = code === 0
                    }

                    Rectangle {
                        id: mediaPreview
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.modelData.kind === "image" ? 76 : 42
                        height: row.modelData.kind === "image" ? 76 : 42
                        radius: 9
                        color: Theme.sunken
                        clip: true
                        visible: row.media

                        Image {
                            anchors.fill: parent
                            source: row.thumbnailReady ? `file://${row.thumbnailPath}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            visible: row.modelData.kind === "image" && row.thumbnailReady
                        }
                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.kind === "video" ? ""
                                : row.modelData.kind === "image" ? "" : ""
                            color: Theme.accent
                            font.family: Theme.icons
                            font.pixelSize: row.modelData.kind === "image" ? 22 : 18
                            visible: row.modelData.kind !== "image" || !row.thumbnailReady
                        }
                    }

                    Text {
                        anchors.left: row.media ? mediaPreview.right : parent.left
                        anchors.right: hint.left
                        anchors.leftMargin: row.media ? 12 : 14
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.media
                            ? `${row.modelData.kind === "image" ? "Image" : row.modelData.kind === "video" ? "Video" : "Binary"} · ${row.modelData.preview}`
                            : row.modelData.preview
                        textFormat: Text.PlainText
                        color: selected ? Theme.fg : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                    Text {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "paste  ↵"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        visible: row.selected
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = row.index
                        onClicked: root.activate(row.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.entries.length ? "No matches" : "Copy something to get started"
                    color: Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    visible: root.resultRows.length === 0
                }
            }

            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 40

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.borderIdle
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑↓ select   ↵ paste   esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ctrl+delete clear"
                    color: clearArea.containsMouse ? Theme.red : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearHistory()
                    }
                }
            }
        }
    }
}
