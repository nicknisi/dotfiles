// BatteryMenu.qml - the charge limit (the control center's battery hand-off;
// the classic bars' anchored host shows it on its frame, PLAN M4).
//
// In the island's material: hints Adwaita 12 `inkDim`, the actions Kit
// PillButtons (quiet: `fillLow` with a hairline ring), the top-up ones in
// `accent` ink while they can run.
import QtQuick
import QtQuick.Layouts
import qs
import qs.Kit

BarMenu {
    id: menu
    title: "Battery"
    subtitle: `${Battery.statusText} · ${Battery.percent}%` + (Battery.timeText ? ` · ${Battery.timeText}` : "")
    onShownChanged: Battery.controlsVisible = shown

    component Hint: Text {
        textFormat: Text.PlainText
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Hint {
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
            PillButton {
                id: choice
                required property int modelData
                objectName: "topUp" + modelData
                Layout.fillWidth: true
                size: 34
                tone: "quiet"
                enabled: Battery.care.supported && Battery.care.mode === "Custom" && Battery.pluggedIn
                    && Battery.percent < modelData && !Battery.care.target && !Battery.busy
                    && (modelData !== 80 || (Battery.care.end === 80 && Battery.percent < 75))
                ink: enabled ? Tokens.accent : Tokens.fg
                text: modelData === 80 ? "Top up to 80%" : "Charge to 100%"
                onClicked: Battery.topUp(modelData)
            }
        }
    }
    PillButton {
        id: cancel
        objectName: "stopTopUp"
        visible: Battery.care.target > 0
        enabled: !Battery.busy
        Layout.fillWidth: true
        size: 34
        tone: "quiet"
        ink: Tokens.accent
        text: Battery.care.recovery ? "Restore battery care" : "Cancel top-up"
        onClicked: Battery.stopTopUp()
    }
    Hint {
        text: Battery.busy ? "Authorize in the system dialog…"
            : !Battery.pluggedIn ? "Connect a charger to top up."
            : Battery.care.supported && Battery.care.mode !== "Custom" && !Battery.care.target
                ? "Select Custom charging mode in BIOS to enable battery care."
            : "Requires administrator authorization. Usual settings return automatically. The 80% top-up is available below 75% with an 80% cap."
    }
    Hint { visible: Battery.error !== ""; text: Battery.error; color: Tokens.bad }
}
