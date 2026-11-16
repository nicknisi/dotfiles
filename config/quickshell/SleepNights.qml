// SleepNights.qml - SleepFade.qml's overlay: one black layer per screen, on
// the overlay layer above the bar and the island (the session lock's
// surfaces are above it), loaded by URL so SleepFade.qml compiles where no
// layer-shell backend exists.
//
// Unmapped while open (the window is not visible: no surface, no input
// region, nothing composited); mapped while closing, closed and opening.
// It takes the pointer only while it darkens or is dark (a press on a
// half-black screen goes nowhere), and lets it through while it fades up.
// Never the keyboard.
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: nights

    // The SleepFade that loaded it.
    property var fade: null
    readonly property int count: windows.instances.length

    Variants {
        id: windows
        model: nights.fade ? Quickshell.screens : []
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: nights.fade?.mapped ?? false
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell-sleep"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                width: nights.fade?.blocking ? win.width : 0
                height: nights.fade?.blocking ? win.height : 0
            }
            Rectangle {
                objectName: "sleepNight"
                anchors.fill: parent
                color: Tokens.night
                opacity: nights.fade?.level ?? 0
                Behavior on opacity {
                    enabled: (nights.fade?.pinned ?? -1) < 0
                    NumberAnimation {
                        duration: nights.fade?.fadeMs ?? 400
                        easing.type: Easing.InOutSine
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: nights.fade?.blocking ?? false
            }
        }
    }
}
