import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

BarMenu {
    id: menu
    property string section: "Machines"
    property int cursor: 0
    readonly property var routes: [{ id: "direct", name: "Direct connection", target: "", selected: Tailscale.exitName === "", detail: "No exit node" }]
        .concat(Tailscale.exitNodes.map(n => ({ id: n.id, name: n.name, target: n.ipv4 || n.dns || n.ipv6, selected: n.exitNode, detail: n.online ? "Your tailnet" : "Selected, offline" })))
        .concat(Tailscale.regions.map(n => ({ id: n.id, name: n.name, target: n.target, selected: n.selected, detail: "Mullvad" })))
    readonly property var rows: {
        const source = section === "Accounts" ? Tailscale.accounts : section === "Routes" ? (Tailscale.running ? routes : []) : Tailscale.peers;
        const needle = search.text.toLowerCase();
        return source.filter(n => (n.name || n.label || "").toLowerCase().includes(needle));
    }
    readonly property var selected: rows[cursor] ?? null
    onRowsChanged: cursor = Math.max(0, Math.min(cursor, rows.length - 1))
    onSectionChanged: { cursor = 0; search.text = ""; }
    onShownChanged: {
        if (shown) { Tailscale.refresh(); Qt.callLater(() => menu.forceActiveFocus()); }
    }

    function activate(index) {
        cursor = index;
        if (!selected || Tailscale.busy) return;
        if (section === "Accounts") Tailscale.switchAccount(selected.id);
        else if (section === "Routes" && (selected.id === "direct" || selected.target)) Tailscale.setExitNode(selected.target);
        else Tailscale.copy(selected.ipv4 || selected.ipv6, "machine IP");
    }
    function send() {
        if (!selected?.canSend || Tailscale.busy || Tailscale.sending) return;
        files.peerId = selected.id;
        files.profile = Tailscale.accountId;
        files.title = "Send to " + selected.name;
        files.open();
    }
    Keys.onPressed: event => {
        if (search.activeFocus) return;
        const key = event.key;
        if (key === Qt.Key_J || key === Qt.Key_Down) cursor = Math.max(0, Math.min(rows.length - 1, cursor + 1));
        else if (key === Qt.Key_K || key === Qt.Key_Up) cursor = Math.max(0, cursor - 1);
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) activate(cursor);
        else if (key === Qt.Key_T) Tailscale.toggle();
        else if (key === Qt.Key_R) Tailscale.refresh();
        else if (section === "Machines" && selected) {
            if (key === Qt.Key_C) Tailscale.copy(selected.ipv4 || selected.ipv6, "machine IP");
            else if (key === Qt.Key_N) Tailscale.copy(selected.name, "machine name");
            else if (key === Qt.Key_D) Tailscale.copy(selected.dns, "DNS name");
            else if (key === Qt.Key_S) send();
            else return;
        } else return;
        event.accepted = true;
    }

    component Label: Text {
        textFormat: Text.PlainText
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        elide: Text.ElideRight
        Layout.alignment: Qt.AlignVCenter
    }
    component Chip: BarModule {
        id: chip
        property string caption: text
        implicitHeight: 28
        cornerRadius: 12
        Label { text: chip.caption; color: chip.enabled ? Theme.fg : Theme.secondary }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 76
        radius: 22
        color: Theme.glowFill
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            TailscaleIcon {
                connected: Tailscale.running
                working: Tailscale.busy
                playful: heroHover.hovered
                implicitWidth: 28
                implicitHeight: 28
                HoverHandler { id: heroHover }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { text: Tailscale.self.name || "Tailscale"; font.pixelSize: Theme.fontSize + 3; font.bold: true; Layout.fillWidth: true }
                Label {
                    text: Tailscale.running ? `${Tailscale.peers.length} machines in reach` : Tailscale.stateText
                    color: Theme.secondary
                    Layout.fillWidth: true
                }
            }
            Chip {
                objectName: "tailscaleToggle"
                text: Tailscale.needsLogin ? "Sign in to Tailscale" : Tailscale.running ? "Disconnect Tailscale" : "Connect Tailscale"
                caption: Tailscale.needsLogin ? "Sign in" : Tailscale.running ? "On" : "Off"
                highlighted: Tailscale.running
                enabled: Tailscale.installed && !Tailscale.busy && !Tailscale.statusError
                onClicked: Tailscale.toggle()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: Tailscale.accountName || "Your private network"
            color: Theme.secondary
            font.pixelSize: Theme.fontSize - 3
            Layout.fillWidth: true
        }
        Chip {
            visible: !!Tailscale.self.ipv4
            text: "Copy this machine's IP"
            caption: Tailscale.self.ipv4 || ""
            onClicked: Tailscale.copy(Tailscale.self.ipv4, "your IP")
        }
        Chip { text: "Refresh Tailscale"; caption: "↻"; enabled: !Tailscale.refreshing && !Tailscale.busy; onClicked: Tailscale.refresh() }
    }
    Label {
        Layout.fillWidth: true
        visible: !!Tailscale.exitName
        text: "Via " + Tailscale.exitName
        color: Theme.cyan
    }
    Label {
        Layout.fillWidth: true
        visible: !!Tailscale.error || !!Tailscale.message
        text: Tailscale.error || Tailscale.message
        color: Tailscale.error ? Theme.red : Theme.accent
        wrapMode: Text.Wrap
        maximumLineCount: 5
    }
    Repeater {
        model: Tailscale.status.health ?? []
        Label {
            required property string modelData
            Layout.fillWidth: true
            text: modelData
            color: Theme.yellow
            wrapMode: Text.Wrap
        }
    }
    RowLayout {
        visible: Tailscale.accessDenied || (Tailscale.installed && !!Tailscale.statusError)
        Layout.fillWidth: true
        Chip {
            visible: Tailscale.accessDenied
            text: "Authorize operator"
            enabled: !Tailscale.busy
            onClicked: Tailscale.authorize()
        }
        Chip {
            visible: !!Tailscale.statusError && !Tailscale.accessDenied
            text: "Start service"
            enabled: !Tailscale.busy
            onClicked: Tailscale.startService()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ["Machines", "Routes", "Accounts"]
            Chip {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                highlighted: menu.section === modelData
                onClicked: menu.section = modelData
            }
        }
    }
    TextField {
        id: search
        objectName: "tailscaleSearch"
        Layout.fillWidth: true
        implicitHeight: 30
        placeholderText: menu.section === "Routes" ? "Find a machine or Mullvad region" : "Find " + menu.section.toLowerCase()
        Accessible.name: placeholderText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
        color: Theme.fg
        placeholderTextColor: Theme.secondary
        selectionColor: Theme.accent
        selectedTextColor: Theme.surface
        background: Rectangle { radius: 12; color: Theme.sunken; border.width: search.activeFocus ? 1 : 0; border.color: Theme.accent }
        onTextChanged: menu.cursor = 0
        onAccepted: { menu.activate(menu.cursor); menu.forceActiveFocus(); }
        Keys.onEscapePressed: { text = ""; menu.forceActiveFocus(); }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 184)
        implicitHeight: contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: menu.rows
        currentIndex: menu.cursor
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        spacing: 3
        delegate: BarModule {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 43
            cornerRadius: 14
            highlighted: index === menu.cursor
            text: (modelData.name || modelData.label) + (modelData.selected ? ", selected" : "")
            enabled: !Tailscale.busy
            onClicked: menu.activate(index)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: row.modelData.name || row.modelData.label; Layout.fillWidth: true; font.bold: row.modelData.selected === true }
                Label {
                    text: row.modelData.detail || row.modelData.account || row.modelData.ipv4 || row.modelData.ipv6 || ""
                    color: Theme.secondary
                    font.pixelSize: Theme.fontSize - 3
                    Layout.fillWidth: true
                }
            }
            Label {
                text: row.modelData.selected ? "✓" : menu.section === "Machines" ? (row.modelData.os || "") : ""
                color: Theme.accent
                font.pixelSize: Theme.fontSize - 3
            }
        }
    }
    Label {
        Layout.fillWidth: true
        visible: menu.rows.length === 0
        text: !Tailscale.running && menu.section !== "Accounts" ? "Connect to bring your machines into reach."
            : search.text ? "Nothing by that name." : menu.section === "Accounts" ? "No saved accounts." : "No machines online yet."
        color: Theme.secondary
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.fillWidth: true
        visible: menu.section === "Machines" && menu.selected !== null
        spacing: 3
        Repeater {
            model: [ { key: "ipv4", label: "IPv4" }, { key: "ipv6", label: "IPv6" }, { key: "name", label: "Name" }, { key: "dns", label: "DNS" } ]
            Chip {
                required property var modelData
                text: "Copy " + modelData.label
                caption: modelData.label
                enabled: !!menu.selected?.[modelData.key]
                onClicked: Tailscale.copy(menu.selected[modelData.key], modelData.label)
            }
        }
        Item { Layout.fillWidth: true }
        Chip {
            objectName: "tailscaleSend"
            text: "Send files"
            caption: Tailscale.sending ? "Sending" : "Send ↑"
            highlighted: true
            enabled: menu.selected?.canSend === true && !Tailscale.busy && !Tailscale.sending
            onClicked: menu.send()
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Chip { text: "Open Tailscale admin console"; caption: "Admin ↗"; onClicked: Qt.openUrlExternally("https://login.tailscale.com/admin/machines") }
        Item { Layout.fillWidth: true }
        Chip {
            visible: Tailscale.status.fileSharing === true
            text: "Open Taildrop downloads"
            caption: Tailscale.receiving ? "Inbox ↓" : "Inbox"
            enabled: !!Tailscale.downloads
            onClicked: Quickshell.execDetached(["xdg-open", Tailscale.downloads])
        }
    }
    Label {
        Layout.fillWidth: true
        text: Tailscale.status.fileSharing ? "Taildrop lands in Downloads. j/k move · c copy · s send"
            : "j/k move · enter select · t toggle · r refresh"
        font.pixelSize: Theme.fontSize - 4
        color: Theme.secondary
        wrapMode: Text.Wrap
    }

    FileDialog {
        id: files
        objectName: "taildropFiles"
        property string peerId: ""
        property string profile: ""
        fileMode: FileDialog.OpenFiles
        onAccepted: Tailscale.sendFiles(peerId, profile, selectedFiles.map(url => String(url)))
    }
}
