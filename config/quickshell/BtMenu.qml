// BtMenu.qml - the bluetooth device picker.
//
// Three sections, because the useful action differs per section: connected
// devices disconnect, paired ones connect, everything else pairs. One click on
// a row does whatever that row's state implies; Bt.activate holds that decision
// so this file stays presentation.
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    menuWidth: 320
    title: "Bluetooth"
    subtitle: Bt.present ? Bt.adapter.name : "no adapter"

    onShownChanged: {
        // Keeps a pairing agent alive while the picker is up.
        Bt.pickerOpen = menu.shown;
        // A scan left running in the background keeps the radio busy and audibly
        // degrades anything already connected, so it does not outlive the window
        // it was started from.
        if (!menu.shown && Bt.adapter) Bt.adapter.discovering = false;
    }

    // The radio switch, parked in the header.
    accessory: Rectangle {
        id: power
        implicitWidth: 34
        implicitHeight: 18
        radius: 9
        visible: Bt.present
        opacity: Bt.settling ? 0.5 : 1
        color: Bt.enabled ? Theme.glowFill : Theme.raised
        border.width: 1
        border.color: Bt.enabled ? Theme.borderActive : Theme.muted

        Rectangle {
            width: 12
            height: 12
            radius: 6
            y: 3
            x: Bt.enabled ? power.width - width - 3 : 3
            color: Bt.enabled ? Theme.accent : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
        }

        MenuAction {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !Bt.settling
            Accessible.name: Bt.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on"
            onClicked: Bt.adapter.enabled = !Bt.enabled
        }
    }

    component DeviceRow: Rectangle {
        id: row

        required property var modelData
        readonly property var device: row.modelData

        readonly property int battery: Bt.batteryOf(row.device)
        readonly property bool known: row.device.paired || row.device.bonded
        readonly property bool busy: row.device.pairing
            || row.device.state === BluetoothDeviceState.Connecting
            || row.device.state === BluetoothDeviceState.Disconnecting

        // Hover has to account for the forget button stealing it from the row.
        readonly property bool hovered: hover.containsMouse || forgetArea.containsMouse

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.controlRadius
        color: row.hovered ? Theme.raised : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        // Declared before the RowLayout so the layout's own mouse areas stack
        // above it and win the click.
        MenuAction {
            id: hover
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.name: `${Bt.statusOf(row.device)} ${Bt.labelFor(row.device)}`
            onClicked: Bt.activate(row.device)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.icons
                font.pixelSize: 15
                color: row.device.connected ? Theme.accent : Theme.fg
                text: Icons.forBluetooth(row.device.icon)
                Behavior on color { ColorAnimation { duration: Theme.base } }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.bold: row.device.connected
                color: row.known || row.device.connected ? Theme.fg : Theme.muted
                text: Bt.labelFor(row.device)
            }

            // Only devices that publish org.bluez.Battery1 get a reading, which
            // is most headsets and almost no mice.
            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: row.battery >= 0
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
                color: row.battery <= 20 ? Theme.red : Theme.green
                text: `${row.battery}%`
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: row.busy
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
                color: Theme.yellow
                text: Bt.statusOf(row.device)
            }

            // Unpairing is the one action here that throws away state, so it
            // stays invisible until the pointer is on the row. Fading it rather
            // than hiding it matters: a child MouseArea takes hover away from
            // the row's, so a `visible` bound to the row's own containsMouse
            // would blink itself out of existence the moment you reached it.
            // Opacity does not affect input in Qt Quick, so it can still be hit.
            MenuAction {
                id: forgetArea
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 18
                implicitHeight: 18
                opacity: row.known && row.hovered ? 1 : 0
                enabled: row.known
                cursorShape: Qt.PointingHandCursor
                Accessible.name: `Forget ${Bt.labelFor(row.device)}`
                onClicked: if (row.known) row.device.forget()

                Text {
                    anchors.centerIn: parent
                    font.family: Theme.icons
                    font.pixelSize: 13
                    color: forgetArea.containsMouse ? Theme.red : Theme.muted
                    text: "\u{f0a7a}" // md trash-can-outline
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }
    }

    // ---- the device list --------------------------------------------------
    // Capped and flickable past that, so twenty stale pairings cannot grow the
    // menu off the bottom of the screen. The cap cuts the last row in half on
    // purpose: a sliced row reads as "there is more below" in a way a flush edge
    // does not.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 300)
        visible: Bt.enabled

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list
                // Bound to the Flickable rather than to `parent`, which is its
                // contentItem and is sized by contentWidth.
                width: flick.width
                spacing: 1

                MenuHeading {
                    text: "connected"
                    visible: Bt.connected.length > 0
                }
                Repeater {
                    model: Bt.connected
                    DeviceRow {}
                }

                MenuHeading {
                    text: "paired"
                    visible: Bt.known.length > 0
                }
                Repeater {
                    model: Bt.known
                    DeviceRow {}
                }

                MenuHeading {
                    text: "available"
                    visible: Bt.nearby.length > 0
                }
                Repeater {
                    model: Bt.nearby
                    DeviceRow {}
                }

                MenuHint {
                    visible: Bt.connected.length === 0 && Bt.known.length === 0
                        && Bt.nearby.length === 0
                    Layout.topMargin: 4
                    text: Bt.scanning
                        ? "looking - put the device into pairing mode"
                        : "nothing paired yet, start a scan"
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

    MenuRule { visible: Bt.enabled }

    // ---- the scan toggle ---------------------------------------------------
    // Pinned below the list rather than sitting above the "available" section,
    // where a few paired devices would push it out of view.
    MenuAction {
        Layout.fillWidth: true
        implicitHeight: 24
        visible: Bt.enabled
        cursorShape: Qt.PointingHandCursor
        Accessible.name: Bt.scanning ? "Stop Bluetooth scan" : "Scan for Bluetooth devices"
        onClicked: Bt.adapter.discovering = !Bt.scanning

        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: Theme.raised
            opacity: parent.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            spacing: 8

            Text {
                id: scanGlyph
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.icons
                font.pixelSize: 14
                color: Bt.scanning ? Theme.accent : Theme.muted
                text: "\u{f0450}" // md refresh

                NumberAnimation on rotation {
                    running: Bt.scanning
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1400
                    // An animation stopped mid-turn leaves the glyph tilted, so
                    // straighten it by hand on the way out.
                    onRunningChanged: if (!running) scanGlyph.rotation = 0
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                color: Bt.scanning ? Theme.fg : Theme.muted
                text: Bt.scanning ? "scanning, click to stop" : "scan for devices"
            }
        }
    }

    // Quickshell exposes no agent callbacks, so there is nowhere to draw a
    // passkey prompt. Say so, rather than letting a device fail to pair for no
    // visible reason.
    MenuHint {
        visible: Bt.enabled && Bt.scanning
        text: "a device that asks for a typed passkey has to be paired with bluetoothctl"
    }

    MenuHint {
        visible: !Bt.enabled
        text: Bt.present ? "radio is off" : "no bluetooth adapter found"
    }
}
