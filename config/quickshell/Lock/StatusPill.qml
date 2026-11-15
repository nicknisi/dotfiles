import QtQuick
import qs
import qs.Kit

// StatusPill.qml - Wi-Fi, battery, Suspend and Power on the lock screen
// (PLAN M8, control-lock 4.4): bottom right, 24 from the edges.
//
//   ( 📶  🔋 25%  (☾) (⏻) )   52 high, radius 26, surface, hairline, the one
//                             shadow; padding 0 8 0 18, gap 6
//
// Wi-Fi 14 by bars (wifi1 / wifi2 / wifi, CcData.wifiIcon), wifiOff with the
// radio off, nothing with no device. Battery group: margin 0 10 0 8, gap 5,
// the icon 14 and the percent in Monaspace 12; hidden with no battery.
// Suspend and Power: 36 circles in `fillLow`, the glyph 16 in `fg`.
//
// `status`: { wifi: { present, radioOn, icon }, battery: { present, percent,
// icon } }. Presses come out as suspend() and power(); the host runs them.
//
// QtQuick only (qmltestrunner loads it).
Surface {
    id: pill

    property var status: ({})

    readonly property bool wifiShown: pill.status?.wifi?.present === true
    readonly property bool batteryShown: pill.status?.battery?.present === true
    readonly property alias suspendButton: suspendButton
    readonly property alias powerButton: powerButton

    signal suspend
    signal power

    height: 52
    width: Math.ceil(row.implicitWidth + 18 + 8)
    radius: 26

    Accessible.role: Accessible.Grouping
    Accessible.name: "Status"

    Row {
        id: row
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.wifiShown
            name: pill.status?.wifi?.radioOn === false ? "wifiOff" : String(pill.status?.wifi?.icon || "wifi")
            size: 14
            color: Tokens.fg
            Accessible.role: Accessible.Indicator
            Accessible.name: pill.status?.wifi?.radioOn === false ? "Wi-Fi off" : "Wi-Fi"
        }

        // The battery group, with its own margins (0 10 0 8).
        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.batteryShown
            width: battery.implicitWidth + 8 + 10
            height: battery.implicitHeight
            Row {
                id: battery
                x: 8
                spacing: 5
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: String(pill.status?.battery?.icon || "batteryFull")
                    size: 14
                    color: Tokens.fg
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Number(pill.status?.battery?.percent) || 0) + "%"
                    color: Tokens.fg
                    textFormat: Text.PlainText
                    font.family: "Monaspace Argon"
                    font.pixelSize: 12
                }
            }
            Accessible.role: Accessible.Indicator
            Accessible.name: "Battery " + Math.round(Number(pill.status?.battery?.percent) || 0) + "%"
        }

        LockButton {
            id: suspendButton
            objectName: "lockSuspend"
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            iconName: "moon"
            iconSize: 16
            fill: Tokens.fillLow
            ink: Tokens.fg
            label: "Suspend"
            onActivated: pill.suspend()
        }
        LockButton {
            id: powerButton
            objectName: "lockPower"
            anchors.verticalCenter: parent.verticalCenter
            size: 36
            iconName: "power"
            iconSize: 16
            fill: Tokens.fillLow
            ink: Tokens.fg
            label: "Power menu"
            onActivated: pill.power()
        }
    }
}
