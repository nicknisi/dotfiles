import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "lib/Dictation.js" as Dictation

// VoxtypeOsd.qml - the bottom popup for dictation from the voxtype daemon, in
// the classic bar modes.
//
// A passive view of the existing daemon. Copilot still records and types
// through voxtype directly. Launcher-owned recordings already have their UI.
// Which surface shows a session is lib/Dictation.js: this window in pill,
// full and rail, the island's dict state in island mode (PLAN M3). The card
// itself is VoxtypeCard.qml, so tests/voxtype-osd.sh can build it offscreen.
//
// Input policy: no keyboard focus, no exclusive zone, an empty input region.
// Dictation types into the focused window, so this must never take focus or
// a click.
PanelWindow {
    id: root
    required property var voice
    readonly property string phase: voice.daemonListening ? "listening" : "transcribing"
    readonly property string label: phase === "listening" ? "Listening…" : "Finishing transcript…"
    // The daemon side: a session the shell should show somewhere.
    readonly property bool wanted: Dictation.phase(voice) !== ""

    visible: Dictation.surface(Dictation.phase(voice), Prefs.barMode) === "osd"
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

    VoxtypeCard {
        anchors.fill: parent
        voice: root.voice
        phase: root.phase
        label: root.label
        shown: root.visible
    }
}
