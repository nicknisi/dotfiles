// NetMenu.qml - the wifi picker, replacing the hand-off to nmtui in a terminal.
//
// Quickshell 0.3.1 talks to NetworkManager over D-Bus, so connecting, forgetting
// and passphrase entry all happen here without shelling out.
//
// A remembered network connects on one click. An unknown secured one opens a
// passphrase field inline rather than in a second window, because the menu
// already holds keyboard focus through its grab.
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu
    signal navigate(string page)

    menuWidth: 320
    title: "Network"
    subtitle: {
        if (!Net.radioOn) return "wifi off";
        return Net.connected ? Net.ssid : "not connected";
    }

    // The SSID currently asking for a passphrase, or "". Only one at a time, and
    // cleared whenever the menu closes so a typed secret never outlives it.
    property string asking: ""
    onShownChanged: {
        if (!menu.shown) menu.asking = "";
        // NetworkManager only rescans on its own schedule otherwise, so an open
        // picker would show whatever was cached when something else last asked.
        if (Net.device) Net.device.scannerEnabled = menu.shown;
    }

    // The radio switch, parked in the header.
    accessory: Rectangle {
        id: power
        implicitWidth: 34
        implicitHeight: 18
        radius: 9
        color: Net.radioOn ? Theme.glowFill : Theme.raised
        border.width: 1
        border.color: Net.radioOn ? Theme.borderActive : Theme.muted

        Rectangle {
            width: 12
            height: 12
            radius: 6
            y: 3
            x: Net.radioOn ? power.width - width - 3 : 3
            color: Net.radioOn ? Theme.accent : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Networking.wifiEnabled = !Net.radioOn
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 300)
        visible: Net.radioOn

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list
                width: flick.width
                spacing: 1

                Repeater {
                    model: Net.networks

                    ColumnLayout {
                        id: entry
                        required property var modelData
                        readonly property var network: entry.modelData
                        readonly property bool asking: menu.asking === entry.network.name

                        Layout.fillWidth: true
                        spacing: 0

                        Rectangle {
                            id: row
                            readonly property bool hovered: hover.containsMouse || forgetArea.containsMouse

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.controlRadius
                            color: row.hovered ? Theme.raised : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.quick } }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const n = entry.network;
                                    if (n.connected) {
                                        n.disconnect();
                                    } else if (n.known || !Net.secured(n)) {
                                        n.connect();
                                    } else {
                                        // Toggle, so a second click on the row
                                        // backs out of the passphrase field.
                                        menu.asking = entry.asking ? "" : n.name;
                                        psk.text = "";
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.borderWidth
                                height: parent.height - 10
                                color: Theme.borderActive
                                visible: entry.network.connected
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 8

                                // Four rungs drawn as text, so the strength sits
                                // on the same baseline as everything else.
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: Theme.icons
                                    font.pixelSize: 14
                                    color: entry.network.connected ? Theme.accent
                                         : (Net.barsFor(entry.network) >= 3 ? Theme.green : Theme.yellow)
                                    text: "\u{f05a9}" // md wifi
                                    opacity: 0.35 + 0.65 * (Net.barsFor(entry.network) / 4)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: entry.network.connected
                                    color: entry.network.connected || entry.network.known
                                         ? Theme.fg : Theme.muted
                                    text: entry.network.name
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: Net.busy(entry.network)
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 3
                                    color: Theme.yellow
                                    text: "working"
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: Net.secured(entry.network)
                                    font.family: Theme.icons
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    text: "\uf023" // fa lock
                                }

                                // Only remembered networks have anything to
                                // forget. Same fade-not-hide trick as BtMenu.
                                MouseArea {
                                    id: forgetArea
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    opacity: entry.network.known && row.hovered ? 1 : 0
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (entry.network.known) entry.network.forget()

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: Theme.icons
                                        font.pixelSize: 13
                                        color: forgetArea.containsMouse ? Theme.red : Theme.muted
                                        text: "\u{f0a7a}" // md trash-can-outline
                                    }

                                    Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                                }
                            }
                        }

                        // ---- passphrase ---------------------------------
                        // Unfolds under its own row, so it is obvious which
                        // network the field belongs to.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: entry.asking ? 2 : 0
                            Layout.bottomMargin: entry.asking ? 4 : 0
                            implicitHeight: entry.asking ? 26 : 0
                            clip: true
                            radius: Theme.controlRadius
                            color: Theme.sunken
                            border.width: 1
                            border.color: Theme.borderActive

                            Behavior on implicitHeight {
                                NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic }
                            }

                            TextInput {
                                id: psk
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                visible: entry.asking
                                focus: entry.asking
                                echoMode: TextInput.Password
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                color: Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.surface

                                onAccepted: {
                                    entry.network.connectWithPsk(psk.text);
                                    psk.text = "";
                                    menu.asking = "";
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: psk.text === ""
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    color: Theme.muted
                                    text: "passphrase, then enter"
                                }
                            }
                        }
                    }
                }

                MenuHint {
                    visible: Net.networks.length === 0
                    Layout.topMargin: 4
                    text: "no networks in range"
                }
            }
        }

        Rectangle {
            readonly property real overflow: flick.contentHeight - flick.height
            anchors.right: parent.right
            width: 3
            color: Theme.muted
            visible: overflow > 0
            height: Math.max(24, flick.height * flick.height / flick.contentHeight)
            y: visible ? (flick.contentY / overflow) * (flick.height - height) : 0
        }
    }

    MenuHint {
        visible: !Net.radioOn
        text: "wifi radio is off"
    }

    BarModule {
        id: tailscaleEntry
        Layout.fillWidth: true
        implicitHeight: 44
        cornerRadius: 16
        highlighted: true
        text: "Tailscale controls"
        onClicked: menu.navigate("tailscale")
        TailscaleIcon {
            Layout.alignment: Qt.AlignCenter
            connected: Tailscale.running
            playful: tailscaleEntry.hovered
            working: Tailscale.busy
            tint: Tailscale.error || Tailscale.needsLogin ? Theme.yellow : Tailscale.running ? Theme.accent : Theme.secondary
        }
        Text {
            Layout.fillWidth: true
            text: "Tailscale"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            color: Theme.fg
        }
        Text {
            text: Tailscale.stateText + "  ›"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
            color: Theme.secondary
        }
    }
}
