import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu
    title: "Battery"
    subtitle: `${Battery.statusText} · ${Battery.percent}%` + (Battery.timeText ? ` · ${Battery.timeText}` : "")
    onShownChanged: Battery.controlsVisible = shown

    MenuHint {
        text: Battery.care.target
            ? Battery.care.recovery ? "Top-up was interrupted. Restore battery care below."
                : `Topping up to ${Battery.care.target}%. Your usual limits return at the target or when you unplug.`
            : Battery.care.supported
                ? `Battery care: start below ${Battery.care.start}%, stop at ${Battery.care.end}%.`
                : "Top-up controls are not supported on this battery."
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [80, 100]
            BarModule {
                id: choice
                required property int modelData
                objectName: "topUp" + modelData
                Layout.fillWidth: true
                implicitHeight: 40
                enabled: Battery.care.supported && Battery.care.mode === "Custom" && Battery.pluggedIn
                    && Battery.percent < modelData && !Battery.care.target && !Battery.busy
                    && (modelData !== 80 || (Battery.care.end === 80 && Battery.percent < 75))
                text: modelData === 80 ? "Top up to 80%" : "Charge to 100%"
                onClicked: Battery.topUp(modelData)
                Text {
                    text: choice.text
                    color: choice.enabled ? Theme.accent : Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
    }
    BarModule {
        id: cancel
        objectName: "stopTopUp"
        visible: Battery.care.target > 0
        enabled: !Battery.busy
        Layout.fillWidth: true
        implicitHeight: 40
        text: Battery.care.recovery ? "Restore battery care" : "Cancel top-up"
        onClicked: Battery.stopTopUp()
        Text {
            text: cancel.text
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            Layout.alignment: Qt.AlignCenter
        }
    }
    MenuHint {
        text: Battery.busy ? "Authorize in the system dialog…"
            : !Battery.pluggedIn ? "Connect a charger to top up."
            : Battery.care.supported && Battery.care.mode !== "Custom" && !Battery.care.target
                ? "Select Custom charging mode in BIOS to enable battery care."
            : "Requires administrator authorization. Usual settings return automatically. The 80% top-up is available below 75% with an 80% cap."
    }
    MenuHint { visible: Battery.error !== ""; text: Battery.error }
}
