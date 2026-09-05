// Osd.qml - the volume/brightness overlay media-keys.lua asks for in its header.
//
// It watches state rather than being driven by the keybinds, so hypr/media-keys.lua
// needs no edits and the overlay still appears when something else changes volume:
// a scroll on the bar, pavucontrol, a per-app slider.
//
// Everything is suppressed for the first two seconds, otherwise PipeWire binding
// the sink at login reads as a volume change and flashes the OSD on every start.
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    property bool primed: false
    property string mode: ""

    Timer {
        interval: 2000
        running: true
        onTriggered: root.primed = true
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.mode = ""
    }

    function show(which: string) {
        if (!root.primed) return;
        root.mode = which;
        hideTimer.restart();
    }

    // Watching a bound property and reacting to its change signal is less brittle
    // than Connections with hand-written signal handler names.
    property real volume: Audio.volume
    onVolumeChanged: root.show("volume")

    property bool muted: Audio.muted
    onMutedChanged: root.show("volume")

    property bool micMuted: Audio.micMuted
    onMicMutedChanged: root.show("mic")

    property real brightness: Backlight.fraction
    onBrightnessChanged: root.show("brightness")

    PanelWindow {
        anchors { bottom: true }
        margins { bottom: 120 }

        implicitWidth: 280
        implicitHeight: 64

        color: "transparent"
        visible: root.mode !== ""

        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.bg
            border.width: 1
            border.color: Theme.muted

            Row {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.icons
                    font.pixelSize: 22
                    color: {
                        if (root.mode === "mic") return Audio.micMuted ? Theme.red : Theme.green;
                        if (root.mode === "volume" && Audio.muted) return Theme.red;
                        return Theme.fg;
                    }
                    text: {
                        if (root.mode === "brightness") return "\u{f05a8}";      // md white-balance-sunny: reads as a sun at 22px, unlike f185 which looks like a gear
                        if (root.mode === "mic") return Audio.micMuted ? "\uf131" : "\uf130";
                        return Audio.muted ? "\uf026" : "\uf028";
                    }
                }

                Item {
                    width: 160
                    height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.mode !== "mic"

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.muted
                    }
                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: parent.width * Math.max(0, Math.min(1,
                            root.mode === "brightness" ? Backlight.fraction
                            : Audio.muted ? 0 : Audio.volume))
                        color: root.mode === "brightness" ? Theme.yellow : Theme.cyan
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: Theme.fg
                    text: {
                        if (root.mode === "mic") return Audio.micMuted ? "mic off" : "mic on";
                        const v = root.mode === "brightness" ? Backlight.fraction
                                : Audio.muted ? 0 : Audio.volume;
                        return `${Math.round(v * 100)}%`;
                    }
                }
            }
        }
    }
}
