import QtQuick
import qs.Commons
import qs.Ui
import "launcher/ui"

// VoxtypeCard.qml - what VoxtypeOsd.qml draws: the phase and the daemon's
// loudness as a wave. A plain Item, so the offscreen test can build it.
Item {
    id: root
    required property var voice
    property string phase: "listening"
    property string label: ""
    // The wave runs only while the window shows.
    property bool shown: true

    BorderSurface {
        id: frame
        anchors.fill: parent
        anchors.margins: Theme.shadowPadding
        radius: Theme.panelRadius
        SurfaceShadow { surface: frame }
        color: ShellColor.menu.background
        borderSpec: Border.controlSpec("focus", ShellColor.menu.text, ShellColor.accent)
        Accessible.role: Accessible.StaticText
        Accessible.name: "Voxtype: " + root.label

        Row {
            x: 22; y: 16
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: width; radius: width / 2
                color: ShellColor.accent
                opacity: root.phase === "listening" ? 1 : 0.55
                scale: root.phase === "listening" ? 1 + 0.6 * root.voice.level : 1
                Behavior on scale { NumberAnimation { duration: 60 } }
            }
            Text {
                text: root.label
                textFormat: Text.PlainText
                color: ShellColor.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
            }
        }
        VoiceWave {
            objectName: "voxtypeWave"
            x: 22; y: 43
            width: parent.width - 44; height: 40
            visible: root.shown
            mode: root.phase
            level: root.voice.level
            history: root.voice.history
        }
    }
}
