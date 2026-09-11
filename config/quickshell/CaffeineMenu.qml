// Timer choices for the bar's stay-awake control.
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    menuWidth: 320
    title: "Stay awake"
    subtitle: Caffeine.active ? Caffeine.status : "Choose a duration"

    MenuHeading { text: "duration" }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            model: [
                { minutes: 30, label: "30 minutes" },
                { minutes: 60, label: "1 hour" },
                { minutes: 120, label: "2 hours" },
                { minutes: 240, label: "4 hours" },
                { minutes: -1, label: "Until turned off" }
            ]

            BarModule {
                required property var modelData
                Layout.fillWidth: true
                Layout.columnSpan: modelData.minutes < 0 ? 2 : 1
                implicitHeight: 38
                cornerRadius: 12
                highlighted: Caffeine.selectedMinutes === modelData.minutes
                text: `Keep awake for ${modelData.label}`
                onClicked: {
                    Caffeine.start(modelData.minutes);
                    menu.dismissed();
                }

                Text {
                    Layout.alignment: Qt.AlignCenter
                    text: modelData.label
                    color: Caffeine.selectedMinutes === modelData.minutes ? Theme.accent : Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: modelData.minutes === 60
                }
            }
        }
    }

    BarModule {
        visible: Caffeine.active
        Layout.fillWidth: true
        implicitHeight: 38
        cornerRadius: 12
        text: "Allow normal sleep"
        onClicked: {
            Caffeine.stop();
            menu.dismissed();
        }

        Text {
            Layout.alignment: Qt.AlignCenter
            text: "Turn off"
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }
    }
}
