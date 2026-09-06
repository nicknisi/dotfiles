// The everyday controls, with media first and system telemetry kept secondary.
import Quickshell
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: home

    signal navigate(string page)

    component Label: Text {
        textFormat: Text.PlainText
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
    }

    component Tile: BarModule {
        id: tile
        property string glyph: ""
        property string caption: ""
        property color tint: Theme.accent
        Layout.fillWidth: true
        implicitHeight: 48
        cornerRadius: hovered ? 22 : 16
        highlighted: true

        Text {
            text: tile.glyph
            color: tile.tint
            font.family: Theme.icons
            font.pixelSize: 19
            Layout.alignment: Qt.AlignVCenter
            rotation: tile.hovered ? -8 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Label { text: tile.text; font.bold: true; Layout.fillWidth: true }
            Label { text: tile.caption; color: Theme.secondary; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true }
        }
    }

    MediaCard {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        active: home.shown
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Tile {
            text: "Wi-Fi"
            glyph: Net.radioOn ? "\u{f05a9}" : "\u{f05aa}"
            caption: Net.connected ? Net.ssid : (Net.radioOn ? "Not connected" : "Radio off")
            tint: Net.connected ? Theme.accent : Theme.yellow
            onClicked: home.navigate("net")
        }
        Tile {
            visible: Bt.present
            text: "Bluetooth"
            glyph: "\u{f00af}"
            caption: Bt.connected.length ? Bt.labelFor(Bt.primary) : (Bt.enabled ? "No devices" : "Radio off")
            tint: Theme.cyan
            onClicked: home.navigate("bt")
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 10
        BarModule {
            text: Audio.muted ? "Unmute output" : "Mute output"
            enabled: Audio.ready
            onClicked: Audio.sink.audio.muted = !Audio.muted
            Text {
                text: Audio.muted ? "\u{f0581}" : "\u{f057e}"
                font.family: Theme.icons
                font.pixelSize: 18
                color: Audio.muted ? Theme.red : Theme.accent
                Layout.alignment: Qt.AlignCenter
            }
        }
        MenuSlider {
            Layout.fillWidth: true
            label: "Output volume"
            enabled: Audio.ready
            value: Audio.volume
            tint: Audio.muted ? Theme.secondary : Theme.accent
            onMoved: v => Audio.setVolume(Audio.sink, v)
        }
        Label { text: `${Math.round(Audio.volume * 100)}%`; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
        BarModule {
            text: "Audio devices and app volumes"
            onClicked: home.navigate("audio")
            Text { text: "\u{f0142}"; font.family: Theme.icons; font.pixelSize: 16; color: Theme.secondary; Layout.alignment: Qt.AlignCenter }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: Backlight.primed
        Text {
            text: "\u{f05a8}"
            font.family: Theme.icons
            font.pixelSize: 18
            color: Theme.yellow
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignHCenter
        }
        MenuSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            label: "Screen brightness"
            value: Backlight.fraction
            tint: Theme.yellow
            onMoved: v => {
                home.brightnessTarget = Math.max(1, Math.round(v * 100));
                brightnessDebounce.restart();
            }
        }
        Label { text: `${Math.round(Backlight.fraction * 100)}%`; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
        Item { Layout.preferredWidth: 32 }
    }

    // Coalesce drag updates instead of spawning a brightnessctl process for
    // every pointer event. Never set the screen to zero through a slider.
    property int brightnessTarget: 1
    Timer {
        id: brightnessDebounce
        interval: 80
        onTriggered: Quickshell.execDetached(["brightnessctl", "set", `${home.brightnessTarget}%`])
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8
        BarModule {
            Layout.fillWidth: true
            text: "Choose theme"
            cornerRadius: 12
            onClicked: home.navigate("theme")
            Text { text: "\u{f0e0c}"; font.family: Theme.icons; font.pixelSize: 16; color: Theme.accent }
            Label { text: Theme.name || "Theme"; Layout.fillWidth: true }
        }
        Label {
            visible: Battery.present
            text: `${Battery.charging ? "Charging" : "Battery"} ${Battery.percent}%` + (Battery.timeText ? ` · ${Battery.timeText}` : "")
            color: Battery.low ? Theme.red : Theme.secondary
            font.pixelSize: Theme.fontSize - 3
            Layout.maximumWidth: home.width * 0.55
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: 38
        radius: 16
        color: Theme.raised

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10
            Spark { values: Sys.cpuHistory; tint: Sys.cpu > 85 ? Theme.red : Theme.yellow }
            Label { text: `CPU ${Sys.cpu}%`; font.pixelSize: Theme.fontSize - 3; color: Theme.secondary }
            Item { Layout.fillWidth: true }
            Gauge { value: Sys.mem; tint: Sys.mem > 85 ? Theme.red : Theme.cyan }
            Label { text: `Memory ${Sys.mem}%`; font.pixelSize: Theme.fontSize - 3; color: Theme.secondary }
        }
    }
}
