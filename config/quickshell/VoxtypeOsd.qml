import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "launcher/ui"

// A passive view of the existing daemon. Copilot still records and types
// through voxtype directly. Launcher-owned recordings already have their UI.
PanelWindow {
    id: root
    required property var voice
    readonly property string phase: voice.daemonListening ? "listening" : "transcribing"
    readonly property string label: phase === "listening" ? "Listening…" : "Finishing transcript…"

    visible: !voice.active && !voice.osdSuppressed
        && (voice.daemonListening || voice.daemonState === "transcribing")
    implicitWidth: Math.min(440 + 2 * Theme.shadowPadding, screen ? screen.width - 2 * Style.gapsOut : 440 + 2 * Theme.shadowPadding)
    implicitHeight: 100 + 2 * Theme.shadowPadding
    anchors.bottom: true
    margins.bottom: screen ? Math.round(screen.height * 0.1) : 64
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-voxtype-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    BorderSurface {
        id: frame
        anchors.fill: parent
        anchors.margins: Theme.shadowPadding
        radius: Theme.panelRadius
        SurfaceShadow { surface: frame }
        color: Color.menu.background
        borderSpec: Border.controlSpec("focus", Color.menu.text, Color.accent)
        Accessible.role: Accessible.StaticText
        Accessible.name: "Voxtype: " + root.label

        Row {
            x: 22; y: 16
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: width; radius: width / 2
                color: Color.accent
                opacity: root.phase === "listening" ? 1 : 0.55
                scale: root.phase === "listening" ? 1 + 0.6 * root.voice.level : 1
                Behavior on scale { NumberAnimation { duration: 60 } }
            }
            Text {
                text: root.label
                textFormat: Text.PlainText
                color: Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
            }
        }
        VoiceWave {
            objectName: "voxtypeWave"
            x: 22; y: 43
            width: parent.width - 44; height: 40
            visible: root.visible
            mode: root.phase
            level: root.voice.level
            history: root.voice.history
        }
    }
}
